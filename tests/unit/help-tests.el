;;; help-tests.el --- doom/describe-module and the removed doom-docs -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'dired)

(defconst help-test--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "tests/config-dir.el" help-test--root) nil t)
(load (expand-file-name "lisp/doom-lib.el" help-test--root) nil t)
(load (expand-file-name "lisp/lib/help.el" help-test--root) nil t)

(defun help-test--describe (dir)
  "Run `doom/describe-module' with the module at DIR; return (FILE . MAJOR-MODE) of the visited buffer."
  (cl-letf (((symbol-function 'doom-module-locate-path) (lambda (&rest _) dir)))
    (save-window-excursion
      (doom/describe-module (list 'doom :lang 'go))
      (prog1 (cons buffer-file-name major-mode)
        (kill-buffer (current-buffer))))))

(defmacro help-test--with-dir (var &rest body)
  (declare (indent 1))
  `(let ((,var (make-temp-file "help-test" t)))
     (unwind-protect (progn ,@body) (delete-directory ,var t))))

(ert-deftest help/describe-module-visits-readme ()
  (help-test--with-dir dir
    (write-region "* hi\n" nil (expand-file-name "README.org" dir))
    (should (equal (file-truename (car (help-test--describe dir)))
                   (file-truename (expand-file-name "README.org" dir))))))

(ert-deftest help/describe-module-dired-without-readme ()
  (help-test--with-dir dir
    (should (eq (cdr (help-test--describe dir)) 'dired-mode))))

(ert-deftest help/describe-module-missing-dir-errors ()
  (should-error (help-test--describe nil) :type 'user-error)
  (should-error (help-test--describe "/nonexistent/doom-lite-help-test") :type 'user-error))

(defconst help-test--banned '("doom-docs" "doom/docs" "doom/help-search-headings"))

(ert-deftest help/no-mentions-of-removed-docs ()
  (let (hits)
    (dolist (d (list "lisp" "modules" (tcd-config-dir)))
      (dolist (f (directory-files-recursively
                  (expand-file-name d help-test--root) "\\.el\\'"))
        (with-temp-buffer
          (insert-file-contents f)
          (dolist (s help-test--banned)
            (goto-char (point-min))
            (when (search-forward s nil t) (push (cons f s) hits))))))
    (should-not hits)))

;;; help-tests.el ends here
