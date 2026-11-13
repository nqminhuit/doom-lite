;;; emacs/electric/config.el -*- lexical-binding: t; -*-

(defcustom +electric-indent-words '()
  "The list of electric words. Typing these will trigger reindentation of the
current line."
  :type '(repeat string)
  :group '+electric)

(defcustom +electric-continue-comments t
  "If non-nil, RET will continue commented lines."
  :type 'boolean
  :group '+electric)


;;
;;; Packages

(use-package! electric
  :defer t
  :init
  (setq-default electric-indent-chars '(?\n ?\^?))

  :config
  ;; HACK: Makes RET continue comments. `comment-line-break-function' is used
  ;;   instead of `comment-line' (or the rest of the comment API) because it
  ;;   presents the fewest edge cases. Advice is used over remapping RET or
  ;;   `newline-and-indent' because so many packages/modes do their own
  ;;   remappings downstream, and this avoids the risk of overriding them.
  (defadvice! +electric--continue-comments-a (fn &rest args)
    :around #'electric-indent-post-self-insert-function
    (if (not (and electric-indent-mode
                  (eq last-command-event ?\n)
                  +electric-continue-comments
                  (doom-point-in-comment-p (1- (electric--after-char-pos)))
                  (functionp comment-line-break-function)))
        (apply fn args)
      (delete-char -1)
      (funcall comment-line-break-function nil)))

  (add-hook! 'electric-indent-functions
    (defun +electric-indent-words-fn (_c)
      "Indent current line if user has typed one of `+electric-indent-words'."
      (when (and (eolp) +electric-indent-words)
        (save-excursion
          (backward-word)
          (looking-at-p (concat "\\<" (regexp-opt +electric-indent-words))))))))


;;
;;; Auto-pairing

(add-hook 'doom-first-buffer-hook #'electric-pair-mode)
;; Depth -90: must run before the depth-0 function `read--expression' adds
;; to run `eval-expression-minibuffer-setup-hook', or it would undo it.
(add-hook 'minibuffer-setup-hook #'+electric-pair-minibuffer-h -90)
(add-hook 'eval-expression-minibuffer-setup-hook #'+electric-pair-eval-expression-h)
