;;; packages-api-tests.el --- package! and doom-package-pinned-alist behavior -*- lexical-binding: t; -*-

;; Guards the declaration API the backend swap keeps. Needs no sync.

(require 'ert)
(require 'cl-lib)

(defconst pa-test-root
  (expand-file-name "../.." (file-name-directory (or load-file-name buffer-file-name))))

(defvar doom-emacs-dir pa-test-root)
(defvar doom-core-dir (expand-file-name "lisp/" pa-test-root))
(defvar doom-user-dir (file-name-as-directory (make-temp-file "pa-user" t)))
(defvar pa-test-modules-dir (file-name-as-directory (make-temp-file "pa-mods" t))
  "Module root outside the user dir, so modules are not recorded as user-overridden.")
(defvar doom-module-load-path (list pa-test-modules-dir))

(load (expand-file-name "lisp/doom-lib.el" pa-test-root) nil t)
(provide 'doom-straight)
(load (expand-file-name "lisp/doom-modules.el" pa-test-root) nil t)
(load (expand-file-name "lisp/doom-packages.el" pa-test-root) nil t)

(defconst pa-test-module '(:tools . pamod))

(defun pa-test--write (file text)
  (make-directory (file-name-directory file) t)
  (with-temp-file file (insert ";;; -*- lexical-binding: t -*-\n" text)))

(defun pa-test--module-file ()
  (expand-file-name "tools/pamod/packages.el" pa-test-modules-dir))

(defun pa-test--user-file () (expand-file-name "packages.el" doom-user-dir))

(defun pa-test--list (module-text &optional user-text)
  "Read the packages of a temp module (and optionally the user dir)."
  (pa-test--write (pa-test--module-file) module-text)
  (delete-file (pa-test--user-file))
  (when user-text (pa-test--write (pa-test--user-file) user-text))
  (setq doom-modules nil)
  (doom-modules-initialize)
  (doom-module--put pa-test-module
                    :path (file-name-directory (pa-test--module-file)))
  (doom-package-list (append (list pa-test-module) (when user-text '((:user))))))

(defmacro pa-test--with-recipes (&rest body)
  "Run BODY with recipe lookup reduced to what the declarations say."
  `(cl-letf (((symbol-function 'straight-recipes-retrieve) (lambda (&rest _) nil))
             ((symbol-function 'straight-vc-local-repo-name)
              (lambda (recipe) (file-name-nondirectory (plist-get recipe :repo)))))
     ,@body))

(defconst pa-test-pin-a "1111111111111111111111111111111111111111")
(defconst pa-test-pin-b "2222222222222222222222222222222222222222")

(ert-deftest pa-test-package-records-pin-recipe-disable-modules ()
  (let* ((pkgs (pa-test--list
                (format "(package! foo :pin %S :recipe (:host github :repo \"o/foo\"))
(package! bar :disable t)" pa-test-pin-a)))
         (foo (alist-get 'foo pkgs))
         (bar (alist-get 'bar pkgs)))
    (should (equal (plist-get foo :pin) pa-test-pin-a))
    (should (equal (plist-get foo :recipe) '(:host github :repo "o/foo")))
    (should (equal (plist-get foo :modules) (list pa-test-module)))
    (should-not (plist-get foo :disable))
    (should (plist-get bar :disable))
    (should (equal (plist-get bar :modules) (list pa-test-module)))))

(ert-deftest pa-test-built-in-marks-ignore ()
  (let ((pkgs (pa-test--list "(package! eldoc :built-in t)\n(package! plain)")))
    (should (plist-get (alist-get 'eldoc pkgs) :ignore))
    (should-not (plist-get (alist-get 'plain pkgs) :ignore))))

(ert-deftest pa-test-user-declaration-overrides-module ()
  (let* ((pkgs (pa-test--list
                (format "(package! foo :pin %S :recipe (:host github :repo \"o/foo\"))"
                        pa-test-pin-a)
                (format "(package! foo :pin %S :recipe (:host github :repo \"me/foo\"))"
                        pa-test-pin-b)))
         (foo (alist-get 'foo pkgs)))
    (should (equal (plist-get foo :pin) pa-test-pin-b))
    (should (equal (plist-get foo :recipe) '(:host github :repo "me/foo")))
    (should (member pa-test-module (plist-get foo :modules)))
    (should (member '(:user . modules) (plist-get foo :modules)))))

(ert-deftest pa-test-pinned-alist-maps-repos-to-pins ()
  (let ((pkgs (pa-test--list
               (format "(package! foo :pin %S :recipe (:host github :repo \"o/foo.el\"))
(package! bar :pin %S :recipe (:host github :repo \"o/bar\") :disable t)
(package! eldoc :pin %S :built-in t)
(package! unpinned :recipe (:host github :repo \"o/unpinned\"))"
                       pa-test-pin-a pa-test-pin-a pa-test-pin-a))))
    (pa-test--with-recipes
     (let ((doom-packages pkgs))
       (should (equal (doom-package-pinned-alist)
                      `(("foo.el" . ,pa-test-pin-a))))))))

(provide 'packages-api-tests)
;;; packages-api-tests.el ends here
