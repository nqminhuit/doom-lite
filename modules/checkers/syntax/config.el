;;; checkers/syntax/config.el -*- lexical-binding: t; -*-

(add-hook! 'doom-escape-hook :append
  (defun +syntax-check-buffer-h ()
    "Update flymake on ESC in normal mode."
    (ignore  ; always return nil
     (when (bound-and-true-p flymake-mode)
       (ignore-errors (flymake-start t))))))


;;
;;; Flymake

;; sh-script adds `sh-shellcheck-flymake' in the mode body; without the binary it
;; errors on every check. Runs after the body (and covers `bash-ts-mode').
(defun +syntax-drop-missing-shellcheck-h ()
  "Remove the shellcheck flymake backend when shellcheck isn't installed."
  (unless (executable-find sh-shellcheck-program)
    (remove-hook 'flymake-diagnostic-functions #'sh-shellcheck-flymake t)))
(add-hook 'sh-base-mode-hook #'+syntax-drop-missing-shellcheck-h)

(use-package! flymake
  :defer t
  :init
  (add-hook 'prog-mode-hook #'flymake-mode)
  (add-hook 'text-mode-hook #'flymake-mode)

  :config
  (setq flymake-fringe-indicator-position 'right-fringe
        flymake-wrap-around nil)

  ;; Consult the current buffer first, when searching for the next error (rather
  ;; than looking at other buffers first).
  (setq-default next-error-find-buffer-function #'next-error-buffer-unnavigated-current)

  ;; Fix `next-error' and `previous-error' in buffers where flymake is active.
  (setq-hook! 'flymake-mode-hook next-error-function #'flymake-goto-next-error)

  ;; HACK: Disable the emacs-lisp checker in non-project (likely untrusted)
  ;;   buffers to mitigate potential code execution vulnerability during macro
  ;;   expansion. See CVE-2024-53920.
  (defadvice! +syntax--only-check-elisp-buffers-in-projects-a (&rest _)
    "Prevent the elisp checker in non-project buffers (for CVE-2024-53920)."
    :before-while #'elisp-flymake-byte-compile
    (doom-project-p)))


(use-package! flymake-popon
  :hook (flymake-mode . flymake-popon-mode)
  :config
  (setq flymake-popon-method 'popon))
