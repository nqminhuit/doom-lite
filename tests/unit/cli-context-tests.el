;;; cli-context-tests.el --- restoring the CLI context across a restart -*- lexical-binding: t; -*-

(require 'ert)

(defconst clct-root
  (expand-file-name "../.." (file-name-directory (or load-file-name buffer-file-name))))

(defvar doom-local-dir (file-name-as-directory (make-temp-file "clct-local" t)))
(add-hook 'kill-emacs-hook (lambda () (delete-directory doom-local-dir t)))

(load (expand-file-name "lisp/doom.el" clct-root) nil t)
(load (expand-file-name "lisp/doom-lib.el" clct-root) nil t)
(load (expand-file-name "lisp/doom-cli.el" clct-root) nil t)

(defun clct--write (obj)
  (let ((file (make-temp-file "clct-context")))
    (with-temp-file file (prin1 obj (current-buffer)))
    file))

(defun clct--context (prefix)
  (let ((c (make-doom-cli-context)))
    (setf (doom-cli-context-prefix c) prefix)
    c))

(defun clct--saved (prefix state)
  "A context as `exit!' writes it: buffers replaced by their text."
  (let ((c (clct--context prefix)))
    (setf (doom-cli-context-state c) state
          (doom-cli-context-stdin c) ""
          (doom-cli-context-stdout c) ""
          (doom-cli-context-stderr c) "")
    c))

(defun clct--restore-quietly (file)
  (let ((inhibit-message t))
    (doom-cli-context-restore file (clct--context "doom"))))

(ert-deftest cli-context/restores-same-layout ()
  (let* ((file (clct--write (clct--saved "doom" '((:suppress-prompts? . t)))))
         (new (clct--restore-quietly file)))
    (should (alist-get :suppress-prompts? (doom-cli-context-state new)))
    (should-not (file-exists-p file))))

(ert-deftest cli-context/ignores-different-layout ()
  ;; Saved by older code whose struct had one more slot, as `doom up' leaves behind.
  (let* ((old (clct--saved "doom" '((:suppress-prompts? . t))))
         (stale (apply #'record 'doom-cli-context
                       (append (cl-loop for i from 1 below (length old) collect (aref old i))
                               '(extra))))
         (file (clct--write stale))
         (new (clct--restore-quietly file)))
    (should (equal (doom-cli-context-prefix new) "doom"))
    (should-not (doom-cli-context-state new))
    (should-not (file-exists-p file))))

(ert-deftest cli-context/still-rejects-wrong-prefix ()
  (let ((file (clct--write (clct--saved "other" nil))))
    (unwind-protect
        (should-error (clct--restore-quietly file) :type 'doom-cli-error)
      (delete-file file))))

(ert-deftest cli-context/unhandled-error-type-prints-instead-of-crashing ()
  (should (equal (let ((inhibit-message t))
                   (doom-cli-handle-error nil 'doom-cli-error '(wrong-context-prefix nil)))
                 2)))

;;; cli-context-tests.el ends here
