;;; syntax-tests.el --- flymake backend cleanup -*- lexical-binding: t; -*-

(require 'ert)
(require 'sh-script)

(defconst syntax-test--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

;; Evaluate only the hook function; the rest of config.el needs Doom macros.
(with-temp-buffer
  (insert-file-contents (expand-file-name "modules/checkers/syntax/config.el" syntax-test--root))
  (goto-char (point-min))
  (let (form)
    (while (and (not form) (not (eobp)))
      (let ((f (read (current-buffer))))
        (when (and (eq (car-safe f) 'defun)
                   (eq (nth 1 f) '+syntax-drop-missing-shellcheck-h))
          (setq form f))))
    (eval form t)))

(defun syntax-test--sh-backends (program)
  (let ((sh-shellcheck-program program)
        (sh-base-mode-hook (list #'+syntax-drop-missing-shellcheck-h)))
    (with-temp-buffer
      (sh-mode)
      (memq #'sh-shellcheck-flymake flymake-diagnostic-functions))))

(ert-deftest syntax/missing-shellcheck-backend-removed ()
  (should-not (syntax-test--sh-backends "no-such-shellcheck-program")))

(ert-deftest syntax/present-shellcheck-backend-kept ()
  (should (syntax-test--sh-backends "sh")))
