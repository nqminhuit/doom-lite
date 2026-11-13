;;; emacs/electric/autoload.el -*- lexical-binding: t; -*-

;;;###autodef
(defun set-electric! (modes &rest plist)
  "Declare that WORDS (list of strings) or CHARS (lists of chars) should trigger
electric indentation.

Enables `electric-indent-local-mode' in MODES.

\(fn MODES &key WORDS CHARS)"
  (declare (indent defun))
  (dolist (mode (ensure-list modes))
    (let ((hook (intern (format "%s-hook" mode)))
          (fn   (intern (format "+electric--init-%s-h" mode))))
      (cond ((null (car-safe plist))
             (remove-hook hook fn)
             (unintern fn nil))
            ((fset
              fn (lambda ()
                   (when (eq major-mode mode)
                     (setq-local electric-indent-inhibit nil)
                     (cl-destructuring-bind (&key chars words) plist
                       (electric-indent-local-mode +1)
                       (if chars (setq-local electric-indent-chars chars))
                       (if words (setq-local +electric-indent-words words))))))
             (add-hook hook fn))))))

;;;###autoload
(defun +electric-pair-minibuffer-h ()
  "Pair only in the `eval-expression' and `evil-ex' minibuffers.
Symmetric because minibuffer buffers are reused; no-op if the global mode is off."
  (when (default-value 'electric-pair-mode)
    (electric-pair-local-mode
     (if (memq this-command '(eval-expression evil-ex)) 1 -1))))

;;; autoload.el ends here
