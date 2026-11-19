;;; packages-rollback-tests.el --- `doom rollback' -*- lexical-binding: t; -*-

;; Reuses the bump test harness; adds a state dir and a fake doom-emacs-dir checkout.

(load (expand-file-name "packages-bump-tests.el" (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defconst prt-nothing "Nothing to roll back")

(defmacro prt--with-env (&rest body)
  (declare (indent 0))
  `(pbt--with-env
     (let ((doom-state-dir (concat pbt--root "state/"))
           (doom-user-dir (concat pbt--root "user/")))
       (make-directory doom-user-dir t)
       ,@body)))

(defun prt--rollback (&optional answer)
  (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) answer)))
    (doom-packages-rollback)))

(defun prt--bump-two-files ()
  "Bump package a (module file) and b (user file); return (MOD-BEFORE USER-BEFORE A2 B2)."
  (let ((a2 (pbt--commit "a")) (b2 (pbt--commit "b")))
    (pbt--write pbt--module-file (pbt--decl 'a pbt-old " ; 1.2.3"))
    ;; Non-ASCII bytes must survive the round trip.
    (pbt--write pbt--user-file (concat ";; café ü\n" (pbt--decl 'b pbt-old)))
    (let ((before (list (pbt--slurp pbt--module-file) (pbt--slurp pbt--user-file))))
      (should (pbt--bump nil t))
      (append before (list a2 b2)))))

(ert-deftest prt-bump-then-rollback-restores-bytes ()
  (prt--with-env
    (pcase-let ((`(,mod ,user ,a2 ,_b2) (prt--bump-two-files)))
      (should-not (equal (pbt--slurp pbt--module-file) mod))
      (should (file-exists-p (doom-packages--rollback-file)))
      (setq pbt-output nil)
      (should (prt--rollback t))
      (should (equal (pbt--slurp pbt--module-file) mod))
      (should (equal (pbt--slurp pbt--user-file) user))
      (should-not (file-exists-p (doom-packages--rollback-file)))
      (should (string-match-p (format "%s -> %s" (substring a2 0 7) (substring pbt-old 0 7))
                              (pbt--output)))
      (should (string-match-p "Reverts" (pbt--output)))
      (should (equal (pbt--git (concat pbt--root "emacs/") "log" "-1" "--format=%s") "Revert \"Bump a\"")))))

(ert-deftest prt-edited-file-refuses ()
  (prt--with-env
    (prt--bump-two-files)
    (with-temp-file pbt--user-file (insert "edited\n"))
    (let ((module (pbt--slurp pbt--module-file)))
      (should-error (prt--rollback t) :type 'user-error)
      (should (equal (pbt--slurp pbt--user-file) "edited\n"))
      (should (equal (pbt--slurp pbt--module-file) module))
      (should (file-exists-p (doom-packages--rollback-file))))))

(ert-deftest prt-answering-no-changes-nothing ()
  (prt--with-env
    (prt--bump-two-files)
    (let ((module (pbt--slurp pbt--module-file)))
      (should-not (prt--rollback nil))
      (should (equal (pbt--slurp pbt--module-file) module))
      (should (file-exists-p (doom-packages--rollback-file))))))

(ert-deftest prt-no-record ()
  (prt--with-env
    (should-not (prt--rollback t))
    (should (string-match-p prt-nothing (pbt--output)))))

(ert-deftest prt-new-bump-replaces-record ()
  (prt--with-env
    (prt--bump-two-files)
    (let ((first (doom-packages--rollback-read)))
      (pbt--commit "a")
      (pbt--bump nil t)
      (should-not (equal (plist-get first :commits)
                         (plist-get (doom-packages--rollback-read) :commits))))))

(ert-deftest prt-rollback-pushes-revert-of-pushed-bump ()
  (prt--with-env
    (let ((emacs (concat pbt--root "emacs/")) (cfg (concat pbt--root "cfg/")))
      (prt--bump-two-files)
      (should (prt--rollback t))
      (should (equal (pbt--remote-head emacs) (pbt--head emacs)))
      (should (equal (pbt--git cfg "log" "-1" "--format=%s") "Revert \"Bump b\""))
      (should-not (equal (pbt--remote-head cfg) (pbt--head cfg))))))

(ert-deftest prt-rollback-refuses-when-commit-left-history ()
  (prt--with-env
    (prt--bump-two-files)
    (pbt--git (concat pbt--root "emacs/") "reset" "--hard" "--quiet" "HEAD~1")
    (should-error (prt--rollback t) :type 'user-error)
    (should (file-exists-p (doom-packages--rollback-file)))))

(defun prt--conflict-case (repo)
  "Rollback must abort without leaving reverts when REPO has a later conflicting commit."
  (prt--with-env
    (prt--bump-two-files)
    (let* ((dir (concat pbt--root repo "/"))
           (file (concat dir (if (equal repo "emacs") "mod-packages.el" "user-packages.el")))
           (heads (mapcar (lambda (r) (pbt--head (concat pbt--root r "/"))) '("emacs" "cfg"))))
      (pbt--write file (replace-regexp-in-string "\"[0-9a-f]\\{40\\}\"" (format "\"%s\"" (make-string 40 ?3))
                                                 (pbt--slurp file)))
      (pbt--git dir "commit" "--quiet" "-am" "later")
      (setq heads (mapcar (lambda (r) (pbt--head (concat pbt--root r "/"))) '("emacs" "cfg")))
      (should-error (prt--rollback t) :type 'user-error)
      (should (equal heads (mapcar (lambda (r) (pbt--head (concat pbt--root r "/"))) '("emacs" "cfg"))))
      (dolist (r '("emacs" "cfg"))
        (should (equal (pbt--git (concat pbt--root r "/") "status" "--porcelain") ""))
        (should-not (file-exists-p (concat pbt--root r "/.git/REVERT_HEAD"))))
      (should (file-exists-p (doom-packages--rollback-file))))))

(ert-deftest prt-revert-conflict-in-emacs-repo-aborts-cleanly () (prt--conflict-case "emacs"))
(ert-deftest prt-revert-conflict-in-cfg-repo-aborts-cleanly () (prt--conflict-case "cfg"))

(ert-deftest prt-old-byte-level-record-still-rolls-back ()
  (prt--with-env
    (let ((a2 (pbt--commit "a")))
      (pbt--write pbt--module-file (pbt--decl 'a))
      (let* ((before (pbt--slurp pbt--module-file))
             (originals (list (cons pbt--module-file (doom-packages--file-bytes pbt--module-file)))))
        (doom-packages--rewrite-pin 'a pbt-old a2)
        (doom-packages--record-bump (list (list :repo 'a :packages '(a) :old pbt-old :new a2)) originals)
        (should (prt--rollback t))
        (should (equal (pbt--slurp pbt--module-file) before))))))

;;; doom up

(defun prt--up-setup ()
  "Make a remote and a clone as `doom-emacs-dir'; return the clone's dir."
  (let ((remote (concat pbt--root "remote/")) (clone (concat pbt--root "emacs/")))
    (make-directory remote t)
    (pbt--git remote "init" "--quiet" "-b" "main")
    (make-directory (concat remote "mod") t)
    (pbt--write (concat remote "mod/packages.el") (pbt--decl 'a pbt-old))
    (pbt--git remote "add" "-A")
    (pbt--git remote "commit" "--quiet" "-m" "base")
    (pbt--git pbt--root "clone" "--quiet" remote clone)
    (cons remote clone)))

(defun prt--up-pull (remote clone)
  "Add a pin-changing commit to REMOTE, pull it into CLONE; return (FROM . TO)."
  (pbt--write (concat remote "mod/packages.el") (pbt--decl 'a (make-string 40 ?2)))
  (pbt--git remote "commit" "--quiet" "-am" "Bump a for testing")
  (let ((from (doom-packages--checkout-head clone)))
    (pbt--git clone "pull" "--quiet" "--ff-only")
    (let ((to (doom-packages--checkout-head clone)))
      (doom-packages-record-up clone from to)
      (cons from to))))

(ert-deftest prt-up-rollback-resets-head ()
  (prt--with-env
    (pcase-let* ((`(,remote . ,clone) (prt--up-setup))
                 (`(,from . ,_to) (prt--up-pull remote clone)))
      (should (prt--rollback t))
      (should (equal (doom-packages--checkout-head clone) from))
      (should-not (file-exists-p (doom-packages--rollback-file)))
      (should (string-match-p "Bump a for testing" (pbt--output)))
      (should (string-match-p (format "a: %s -> %s" (substring pbt-old 0 7) "2222222") (pbt--output)))
      (should (string-match-p "pulls these commits again" (pbt--output))))))

(ert-deftest prt-up-rollback-refuses-when-head-moved ()
  (prt--with-env
    (pcase-let* ((`(,remote . ,clone) (prt--up-setup))
                 (`(,_from . ,to) (prt--up-pull remote clone)))
      (pbt--write (concat clone "extra.txt") "x")
      (pbt--git clone "add" "-A")
      (pbt--git clone "commit" "--quiet" "-m" "local")
      (should-error (prt--rollback t) :type 'user-error)
      (should-not (equal (doom-packages--checkout-head clone) to))
      (should (file-exists-p (doom-packages--rollback-file))))))

(ert-deftest prt-up-rollback-refuses-with-uncommitted-changes ()
  (prt--with-env
    (pcase-let* ((`(,remote . ,clone) (prt--up-setup))
                 (`(,_from . ,to) (prt--up-pull remote clone)))
      (pbt--write (concat clone "mod/packages.el") "dirty\n")
      (should-error (prt--rollback t) :type 'user-error)
      (should (equal (doom-packages--checkout-head clone) to))
      (should (file-exists-p (doom-packages--rollback-file))))))

(ert-deftest prt-up-with-nothing-pulled-keeps-existing-record ()
  (prt--with-env
    (pcase-let* ((`(,remote . ,clone) (prt--up-setup))
                 (`(,_from . ,_to) (prt--up-pull remote clone)))
      (let ((before (doom-packages--rollback-read))
            (head (doom-packages--checkout-head clone)))
        (doom-packages-record-up clone head head)
        (should (equal (doom-packages--rollback-read) before))))))
