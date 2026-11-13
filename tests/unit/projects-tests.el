;;; projects-tests.el --- doom-project-root/name behavior -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst prt--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defun prt--path (rel) (expand-file-name rel prt--root))

;; Same tests run against the old projectile implementation and the project.el rewrite.
(defconst prt--old (file-exists-p (prt--path "modules/doom/compat/+projectile.el")))
(defvar prt--skip nil "Non-nil (a message) when the old loader cannot run.")

(if prt--old
    (let ((build (prt--path ".local/straight/build-31.1/projectile")))
      (if (not (file-directory-p build))
          (setq prt--skip "projectile build dir missing")
        (add-to-list 'load-path build)
        (require 'projectile)
        (load (prt--path "lisp/doom-lib.el") nil t)
        (load (prt--path "lisp/doom-projects.el") nil t)
        (load (prt--path "lisp/lib/projects.el") nil t)
        (setq projectile-project-root-files '()
              projectile-project-root-files-top-down-recurring '("Makefile"))
        (add-to-list 'projectile-project-root-files-bottom-up ".project")))
  (load (prt--path "lisp/doom-lib.el") nil t)
  (unless (boundp 'doom-profile-state-dir)
    (defvar doom-profile-state-dir (make-temp-file "prt-state" t)))
  (load (prt--path "lisp/doom-projects.el") nil t)
  (load (prt--path "lisp/lib/projects.el") nil t))

(defvar prt--base nil "Fresh temp root holding all fixtures of the running test.")

(defmacro prt--with-fixture (&rest body)
  "Run BODY with `prt--base' a fresh dir and project state isolated from the user's."
  (declare (indent 0))
  `(progn
     (when prt--skip (ert-skip prt--skip))
     (unless (executable-find "git") (ert-skip "git missing"))
     (let* ((prt--base (file-name-as-directory
                        (file-truename (make-temp-file "prt-base" t))))
            ;; Keep fixtures outside `temporary-file-directory', which is ignored as a project.
            (temporary-file-directory (file-truename (make-temp-file "prt-tmp" t)))
            (project-list-file (expand-file-name "projects" temporary-file-directory))
            (default-directory prt--base))
       (when (boundp 'projectile-project-root-cache)
         (clrhash projectile-project-root-cache))
       (unwind-protect (progn ,@body)
         (delete-directory prt--base t)
         (delete-directory temporary-file-directory t)))))

(defun prt--git-repo (name)
  "Create a git repo NAME under `prt--base' with a nested dir; return the repo root."
  (let* ((root (file-name-as-directory (expand-file-name name prt--base))))
    (make-directory (expand-file-name "a/b" root) t)
    (let ((default-directory root))
      (call-process "git" nil nil nil "init" "-q"))
    (write-region "" nil (expand-file-name "a/b/f.txt" root))
    root))

(ert-deftest projects/root-in-git-repo ()
  (prt--with-fixture
    (let ((root (prt--git-repo "repo")))
      (should (file-equal-p root (doom-project-root (expand-file-name "a/b" root)))))))

(ert-deftest projects/root-dot-project-wins ()
  (prt--with-fixture
    (let* ((root (prt--git-repo "repo"))
           (sub (expand-file-name "a" root)))
      (write-region "" nil (expand-file-name ".project" sub))
      (should (file-equal-p sub (doom-project-root (expand-file-name "b" sub)))))))

(ert-deftest projects/root-nil-outside-project ()
  (prt--with-fixture
    (let ((dir (expand-file-name "plain" prt--base)))
      (make-directory dir)
      (should-not (doom-project-root dir)))))

(ert-deftest projects/name-in-git-repo ()
  (prt--with-fixture
    (let ((root (prt--git-repo "myrepo")))
      (should (equal "myrepo" (doom-project-name (expand-file-name "a/b" root)))))))

(ert-deftest projects/name-no-project-is-dash ()
  (prt--with-fixture
    (let ((default-directory (file-name-as-directory
                              (progn (make-directory (expand-file-name "plain" prt--base))
                                     (expand-file-name "plain" prt--base)))))
      (should (equal "-" (doom-project-name))))))

(ert-deftest projects/add-directory-as-project ()
  (prt--with-fixture
    (when prt--old (ert-skip "project.el only"))
    (let ((dir (expand-file-name "plain" prt--base)))
      (make-directory dir)
      (doom/add-directory-as-project dir)
      (should (file-exists-p (expand-file-name ".project" dir)))
      (should (cl-some (lambda (r) (file-equal-p r dir)) (project-known-project-roots))))))

(ert-deftest projects/excluded-root-not-remembered ()
  (prt--with-fixture
    (when prt--old (ert-skip "project.el only"))
    ;; `temporary-file-directory' is rebound by the fixture and thus ignored as a project.
    (let ((dir (expand-file-name "ignored" temporary-file-directory)))
      (make-directory dir)
      (write-region "" nil (expand-file-name ".project" dir))
      (project-remember-project (project-current nil dir))
      (should-not (cl-some (lambda (r) (file-equal-p r dir)) (project-known-project-roots))))))

(ert-deftest projects/find-file-respects-gitignore ()
  (prt--with-fixture
    (when prt--old (ert-skip "project.el only"))
    (let ((root (prt--git-repo "repo")) offered)
      (write-region "ignored.txt\n" nil (expand-file-name ".gitignore" root))
      (write-region "" nil (expand-file-name "ignored.txt" root))
      (write-region "" nil (expand-file-name "kept.txt" root))
      (cl-letf (((symbol-function 'project--read-file-name)
                 (lambda (_pr _prompt all-files &rest _) (setq offered all-files) "")))
        (should-error (doom-project-find-file root) :type 'user-error))
      (let ((names (mapcar #'file-name-nondirectory offered)))
        (should (member "kept.txt" names))
        (should-not (member "ignored.txt" names))))))

(provide 'projects-tests)
;;; projects-tests.el ends here
