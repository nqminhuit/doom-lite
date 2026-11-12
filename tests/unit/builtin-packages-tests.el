;;; builtin-packages-tests.el --- Emacs 31 built-ins are declared :built-in -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst bp-test-packages
  '(eglot eldoc flymake jsonrpc project xref seq external-completion transient compat))

(defconst bp-test-root
  (expand-file-name "../.." (file-name-directory (or load-file-name buffer-file-name))))

(defun bp-test--forms (file)
  "Return all top-level forms read from FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (let (forms)
      (condition-case nil
          (while t (push (read (current-buffer)) forms))
        (end-of-file))
      (nreverse forms))))

(defun bp-test--package-forms (form)
  "Return every `package!' form nested anywhere in FORM."
  (cond ((not (consp form)) nil)
        ((eq (car form) 'package!) (list form))
        (t (let (acc)
             (while (consp form)
               (setq acc (append acc (bp-test--package-forms (car form)))
                     form (cdr form)))
             acc))))

(defun bp-test--declarations ()
  "Return an alist of (NAME . PLIST) for the tracked packages in modules/**/packages.el."
  (let (decls)
    (dolist (file (directory-files-recursively
                   (expand-file-name "modules" bp-test-root) "\\`packages\\.el\\'"))
      (dolist (form (bp-test--forms file))
        (dolist (pkg (bp-test--package-forms form))
          (when (memq (cadr pkg) bp-test-packages)
            (push (list (cadr pkg) file (cddr pkg)) decls)))))
    decls))

(ert-deftest builtin-packages/shipped-with-emacs ()
  ;; Under -Q only Emacs's own load-path is active, so a hit means built in.
  (dolist (name bp-test-packages)
    (let ((lib (locate-library (symbol-name name))))
      (should lib)
      (should (file-in-directory-p lib lisp-directory)))))

(ert-deftest builtin-packages/declared-built-in-without-pin ()
  (let ((decls (bp-test--declarations)))
    (should decls)
    (pcase-dolist (`(,name ,file ,plist) decls)
      (should (eq (plist-get plist :built-in) t))
      (should-not (plist-member plist :pin))
      (ignore file))))

(provide 'builtin-packages-tests)
;;; builtin-packages-tests.el ends here
