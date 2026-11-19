;;; packages-bump-tests.el --- `doom-packages-bump' -*- lexical-binding: t; -*-

;; Runs against temp `file://' git repos and temp packages.el files; no network.

(require 'ert)
(require 'cl-lib)

(defconst pbt-root
  (expand-file-name "../.." (file-name-directory (or load-file-name buffer-file-name))))

(defvar doom-emacs-dir (file-name-as-directory pbt-root))
(defvar doom-core-dir (expand-file-name "lisp/" pbt-root))
(defvar doom-user-dir (file-name-as-directory (make-temp-file "pbt-user" t)))
(defvar doom-data-dir (file-name-as-directory (make-temp-file "pbt-data" t)))
(defvar doom--system-windows-p nil)
(defvar doom-local-dir (file-name-as-directory (make-temp-file "pbt-local" t)))
(defvar doom-module-load-path nil)
(defvar doom-state-dir (file-name-as-directory (make-temp-file "pbt-state" t)))

(add-hook 'kill-emacs-hook
          (lambda ()
            (delete-directory doom-user-dir t)
            (delete-directory doom-data-dir t)
            (delete-directory doom-local-dir t)
            (delete-directory doom-state-dir t)))

(defvar pbt-output nil "Lines the CLI output macros printed, newest first.")
;; Stand-ins for the CLI macros: (print! (kind FMT) ARGS...) or (print! FMT ARGS...).
(defmacro print! (msg &rest args)
  `(push (apply #'format ,(if (consp msg) (cadr msg) msg) (list ,@args)) pbt-output))
(defmacro print-group! (&rest body) (macroexp-progn body))
(defmacro format! (msg &rest args) `(format ,msg ,@args))

(load (expand-file-name "lisp/doom-lib.el" pbt-root) nil t)
(load (expand-file-name "lisp/lib/files.el" pbt-root) nil t)
(load (expand-file-name "lisp/lib/process.el" pbt-root) nil t)
(load (expand-file-name "lisp/doom-modules.el" pbt-root) nil t)
(load (expand-file-name "lisp/doom-packages.el" pbt-root) nil t)

(defconst pbt-git-env
  '("GIT_CONFIG_GLOBAL=/dev/null" "GIT_CONFIG_NOSYSTEM=1"
    "GIT_AUTHOR_NAME=t" "GIT_AUTHOR_EMAIL=t@example.com"
    "GIT_COMMITTER_NAME=t" "GIT_COMMITTER_EMAIL=t@example.com"))
(defconst pbt-old "1111111111111111111111111111111111111111")
(defconst pbt-up-to-date "All pins are current")

(defvar pbt--root nil)
(defvar pbt--module-file nil)
(defvar pbt--user-file nil)

(defun pbt--git (dir &rest args)
  (let ((default-directory (file-name-as-directory dir))
        (process-environment (append pbt-git-env process-environment)))
    (with-temp-buffer
      (unless (zerop (apply #'call-process "git" nil t nil args))
        (error "git %S failed: %s" args (buffer-string)))
      (string-trim (buffer-string)))))

(defun pbt--commit (repo &optional branch)
  "Add a commit to upstream o/REPO (on BRANCH if given) and return its SHA."
  (let ((dir (format "%sup/o/%s.git/" pbt--root repo)))
    (unless (file-directory-p (concat dir ".git"))
      (make-directory dir t)
      (pbt--git dir "init" "--quiet" "-b" "main"))
    (when branch
      (if (equal (ignore-errors (pbt--git dir "branch" "--list" branch)) "")
          (pbt--git dir "checkout" "--quiet" "-b" branch)
        (pbt--git dir "checkout" "--quiet" branch)))
    (with-temp-file (concat dir "f.txt") (insert (format "%s %s" (random) (float-time))))
    (pbt--git dir "add" "-A")
    (pbt--git dir "commit" "--quiet" "-m" "x")
    (prog1 (pbt--git dir "rev-parse" "HEAD")
      (when branch (pbt--git dir "checkout" "--quiet" "main")))))

(defun pbt--read-files ()
  "Stand-in for `doom-package-list': evaluate the temp packages.el files in order."
  (let (alist)
    (dolist (file (doom-packages--package-files))
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (condition-case nil
            (while t
              (pcase (read (current-buffer))
                (`(package! ,name . ,plist)
                 (let ((old (cdr (assq name alist))))
                   (cl-loop for (k v) on plist by #'cddr
                            do (when (or (eq k :pin) v) (setq old (plist-put old k (if (eq k :pin) (eval v) v)))))
                   (setf (alist-get name alist) (plist-put old :declared-in file))))))
          (end-of-file nil))))
    (nreverse alist)))

(defun pbt--recipe (name)
  (format "(:host github :repo \"o/%s\")" name))

(defmacro pbt--with-env (&rest body)
  "Run BODY with module and user packages.el files in temp dirs."
  (declare (indent 0))
  `(let* ((pbt--root (file-name-as-directory (make-temp-file "pbt" t)))
          (pbt--module-file (concat pbt--root "mod-packages.el"))
          (pbt--user-file (concat pbt--root "user-packages.el"))
          (doom-emacs-dir (concat pbt--root "emacs/"))
          (doom-packages-dir (concat pbt--root "pk/"))
          (doom-packages-host-urls
           (list (cons 'github (format "file://%sup/%%s.git" pbt--root))
                 (cons 'codeberg (format "file://%sup/%%s.git" pbt--root))))
          (doom-packages nil)
          (doom-disabled-packages nil)
          (pbt-output nil))
     (unwind-protect
         (cl-letf (((symbol-function 'doom-packages--package-files)
                    (lambda () (cl-remove-if-not #'file-exists-p (list pbt--module-file pbt--user-file))))
                   ((symbol-function 'doom-package-list) #'pbt--read-files))
           ,@body)
       (delete-directory pbt--root t))))

(defun pbt--write (file text)
  (with-temp-file file (insert text)))

(defun pbt--slurp (file)
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(defun pbt--decl (name &optional pin comment extra)
  (format "(package! %s\n  :recipe %s%s\n  :pin \"%s\")%s\n"
          name (pbt--recipe name) (or extra "") (or pin pbt-old) (or comment "")))

(defun pbt--output () (string-join (reverse pbt-output) "\n"))

(defun pbt--pin (name) (plist-get (cdr (assq name doom-packages)) :pin))

(defun pbt--bump (&optional names answer)
  (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) answer)))
    (doom-packages-bump names)))


;;; Tests

(ert-deftest pbt-bumps-only-repos-with-new-commits ()
  (pbt--with-env
    (let ((a (pbt--commit "a")) (b (pbt--commit "b")))
      (pbt--write pbt--module-file (concat (pbt--decl 'a pbt-old) (pbt--decl 'b b)))
      (let ((a2 (pbt--commit "a")))
        (pbt--bump nil t)
        (should (equal (pbt--pin 'a) a2))
        (should (equal (pbt--pin 'b) b))
        (should (string-match-p (regexp-quote (substring a2 0 7)) (pbt--output)))
        (should (string-match-p "1 of 2 repos have updates" (pbt--output)))
        (should (string-match-p "github.com/o/a/compare/" (pbt--output)))
        (should (string-match-p "Bumped 1 repos; syncing" (pbt--output)))
        (ignore a)))))

(ert-deftest pbt-shared-repo-moves-together ()
  (pbt--with-env
    (let ((new (pbt--commit "shared")))
      (pbt--write pbt--module-file
                  (concat "(package! one\n  :recipe (:host github :repo \"o/shared\")\n  :pin \"" pbt-old "\")\n"
                          "(package! two\n  :recipe (:host github :repo \"o/shared\" :files (\"two.el\"))\n  :pin \"" pbt-old "\")\n"))
      (pbt--bump '(one) t)
      (should (equal (pbt--pin 'one) new))
      (should (equal (pbt--pin 'two) new)))))

(ert-deftest pbt-branch-recipe-follows-branch-head ()
  (pbt--with-env
    (pbt--commit "br")
    (let ((feature (pbt--commit "br" "feat")))
      (pbt--write pbt--module-file
                  (concat "(package! br\n  :recipe (:host github :repo \"o/br\" :branch \"feat\")\n  :pin \"" pbt-old "\")\n"))
      (pbt--bump nil t)
      (should (equal (pbt--pin 'br) feature)))))

(ert-deftest pbt-user-override-is-rewritten-in-user-file ()
  (pbt--with-env
    (let ((new (pbt--commit "a")))
      (pbt--write pbt--module-file (pbt--decl 'a pbt-old))
      (pbt--write pbt--user-file (format "(package! a :pin \"%s\")\n" pbt-old))
      (let ((module-before (pbt--slurp pbt--module-file)))
        (pbt--bump nil t)
        (should (equal (pbt--slurp pbt--module-file) module-before))
        (should (string-match-p new (pbt--slurp pbt--user-file)))
        (should (equal (pbt--pin 'a) new))
        (should (string-match-p "outside" (pbt--output)))))))

(ert-deftest pbt-version-comment-handling ()
  (pbt--with-env
    (let ((new (pbt--commit "a")))
      (pbt--commit "b")
      (pbt--write pbt--module-file
                  (concat (pbt--decl 'a pbt-old " ; 4.7.1")
                          (pbt--decl 'b pbt-old " ; keep me")))
      (pbt--bump nil t)
      (let ((text (pbt--slurp pbt--module-file)))
        (should (string-match-p (format ":pin \"%s\")\n" new) text))
        (should-not (string-match-p "4\\.7\\.1" text))
        (should (string-match-p "; keep me" text))))))

(ert-deftest pbt-answering-no-writes-nothing ()
  (pbt--with-env
    (pbt--commit "a")
    (pbt--write pbt--module-file (pbt--decl 'a pbt-old))
    (let ((before (pbt--slurp pbt--module-file)))
      (pbt--bump nil nil)
      (should (string-match-p "1 of 1 repos" (pbt--output)))
      (should (equal (pbt--slurp pbt--module-file) before))
      (should-not (string-match-p "Bumped" (pbt--output))))))

(ert-deftest pbt-unreachable-repo-is-skipped ()
  (pbt--with-env
    (let ((new (pbt--commit "a")))
      (pbt--write pbt--module-file (concat (pbt--decl 'a pbt-old) (pbt--decl 'gone pbt-old)))
      (pbt--bump nil t)
      (should (equal (pbt--pin 'a) new))
      (should (equal (pbt--pin 'gone) pbt-old))
      (should (string-match-p "Could not resolve gone" (pbt--output))))))

(ert-deftest pbt-nothing-to-bump ()
  (pbt--with-env
    (let ((a (pbt--commit "a")))
      (pbt--write pbt--module-file (pbt--decl 'a a))
      (pbt--bump nil t)
      (should (string-match-p pbt-up-to-date (pbt--output))))))

(ert-deftest pbt-unknown-package-is-an-error ()
  (pbt--with-env
    (pbt--write pbt--module-file (pbt--decl 'a))
    (should-error (pbt--bump '(nope) t) :type 'user-error)))

(ert-deftest pbt-unrewritable-pin-skips-its-repo-only ()
  (pbt--with-env
    (let ((new (pbt--commit "a")))
      (pbt--commit "shared")
      (pbt--write pbt--module-file
                  (concat (pbt--decl 'a pbt-old)
                          (format "(package! one\n  :recipe (:host github :repo \"o/shared\")\n  :pin \"%s\")\n" pbt-old)))
      (pbt--write pbt--user-file
                  (format "(package! two\n  :recipe (:host github :repo \"o/shared\")\n  :pin (concat \"%s\" \"%s\"))\n"
                          (substring pbt-old 0 20) (substring pbt-old 20)))
      (let ((before (pbt--slurp pbt--module-file))
            (user-before (pbt--slurp pbt--user-file)))
        (pbt--bump nil t)
        (should (equal (pbt--pin 'a) new))
        (should (equal (pbt--pin 'one) pbt-old))
        (should (equal (pbt--pin 'two) pbt-old))
        (should (string-match-p "Could not resolve shared.*not a literal" (pbt--output)))
        (should (equal (pbt--slurp pbt--user-file) user-before))
        (should-not (equal (pbt--slurp pbt--module-file) before))
        (should (string-match-p (format "\"%s\"" pbt-old) (pbt--slurp pbt--module-file)))))))
