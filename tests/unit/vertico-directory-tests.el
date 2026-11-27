;;; vertico-directory-tests.el --- directory highlighting in file completion -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'subr-x)

(defconst vdt-root (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))
(defconst vdt-config (expand-file-name "modules/completion/vertico/config.el" vdt-root))

(defun vdt--forms ()
  "Return the top-level forms of the vertico config."
  (let (forms)
    (with-temp-buffer
      (insert-file-contents vdt-config)
      (condition-case nil
          (while t (push (read (current-buffer)) forms))
        (end-of-file nil)))
    (nreverse forms)))

(defun vdt--find-defun (form name)
  "Find the `defun' of NAME anywhere inside FORM."
  (cond ((and (consp form) (eq (car form) 'defun) (eq (cadr form) name)) form)
        ((consp form)
         (cl-loop for sub on form
                  when (consp (car sub))
                  thereis (vdt--find-defun (car sub) name)))))

(ert-deftest vdt-directory-fn-applies-own-face ()
  (let ((def (cl-some (lambda (f) (vdt--find-defun f '+vertico-highlight-directory-fn))
                      (vdt--forms))))
    (should def)
    (eval def t)
    (should (eq (get-text-property 0 'face (+vertico-highlight-directory-fn (copy-sequence "foo/")))
                '+vertico-directory))
    (should-not (get-text-property 0 'face (+vertico-highlight-directory-fn (copy-sequence "foo"))))))

(ert-deftest vdt-directory-face-and-category-defined ()
  (let ((text (with-temp-buffer (insert-file-contents vdt-config) (buffer-string))))
    (should (string-match-p "(defface \\+vertico-directory" text))
    (should (string-match-p "(file\n *(\\+vertico-transform-functions \\. \\+vertico-highlight-directory-fn)" text))))

(ert-deftest vdt-no-marginalia-face-in-modules ()
  (should-not (split-string
               (shell-command-to-string
                (format "grep -rl marginalia-file-priv-dir %s"
                        (shell-quote-argument (expand-file-name "modules" vdt-root))))
               "\n" t)))
