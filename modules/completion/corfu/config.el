;;; completion/corfu/config.el -*- lexical-binding: t; -*-

(defcustom +corfu-want-ret-to-confirm t
  "Configure how the user expects RET to behave.

Possible values are:
- t (default): Insert candidate if one is selected, pass-through otherwise;
- nil: Pass-through without inserting;
- `both': Insert candidate if one is selected, then pass-through;
- `minibuffer': Behaves like `both` in the minibuffer and `t` otherwise."
  :type '(choice (const :tag "Insert if selected, passthrough otherwise" t)
                 (const :tag "Passthrough without insertion" nil)
                 (const :tag "Insert if selected, then passthrough" both)
                 (const :tag "Behaves like `both' in minibuffer, `t' otherwise" minibuffer))
  :group '+corfu)

(defcustom +corfu-want-minibuffer-completion t
  "Whether to enable Corfu in the minibuffer.

Possible values are:
- t: enable Corfu only if `completion-at-point' is bound in the minibuffer's
  `current-local-map'.
- nil: Corfu is disabled in the minibuffer.
- aggressive: enable Corfu even when no recognized completion framework is
  active."
  :type '(choice (const :tag "Disabled" nil)
                 (const :tag "Aggressive" aggressive)
                 (const :tag "Only when bound" t))
  :group '+corfu)

(defcustom +corfu-inhibit-auto-functions ()
  "A list of predicate functions that take no arguments.

If any return non-nil, `corfu-auto' will not invoke as-you-type completion."
  :type 'hook
  :group '+corfu)


;;
;;; Packages

(use-package! corfu
  :hook (doom-first-input . global-corfu-mode)
  :config
  (setq corfu-auto t
        global-corfu-modes
        '((not erc-mode
               circe-mode
               help-mode
               gud-mode
               vterm-mode)
          t)
        corfu-cycle t
        corfu-preselect 'prompt
        corfu-count 16
        corfu-max-width 120
        corfu-on-exact-match nil
        corfu-quit-at-boundary 'separator
        corfu-quit-no-match corfu-quit-at-boundary)

  (add-to-list 'completion-category-overrides `(lsp-capf (styles ,@completion-styles)))
  (add-to-list 'corfu-continue-commands #'+corfu/move-to-minibuffer)
  (add-to-list 'corfu-continue-commands #'+corfu/smart-sep-toggle-escape)
  (add-hook 'evil-insert-state-exit-hook #'corfu-quit)

  (defun +corfu--other-completion-active-p ()
    "Return non-nil if another completion framework is already active.

This checks for several completion systems such as mct, vertico,
auth-source’s read-passwd-map, helm, ido, and ivy. When one of these
systems is active, Corfu should not enable its own completion."
    (or (bound-and-true-p mct--active)
        (bound-and-true-p vertico--input)
        (and (featurep 'auth-source)
             (eq (current-local-map) read-passwd-map))
        (and (featurep 'helm-core)
             (helm--alive-p))
        (and (featurep 'ido)
             (ido-active))
        (where-is-internal 'minibuffer-complete (list (current-local-map)))
        (memq #'ivy--queue-exhibit post-command-hook)))

  (defun +corfu-enable-in-minibuffer-p ()
    "Return non-nil if Corfu should be enabled in the minibuffer.

See `+corfu-want-minibuffer-completion'."
    (pcase +corfu-want-minibuffer-completion
      ('nil nil)
      ('aggressive (not (+corfu--other-completion-active-p)))
      (_ (and (where-is-internal #'completion-at-point
                                 (list (current-local-map)))
              (not (+corfu--other-completion-active-p))))))

  (setq global-corfu-minibuffer #'+corfu-enable-in-minibuffer-p)

  ;; HACK: If you want to update the visual hints after completing minibuffer
  ;;   commands with Corfu and exiting, you have to do it manually.
  (defadvice! +corfu--insert-before-exit-minibuffer-a ()
    :before #'exit-minibuffer
    (when (or (and (frame-live-p corfu--frame)
                   (frame-visible-p corfu--frame))
              (and (featurep 'corfu-terminal)
                   (popon-live-p corfu-terminal--popon)))
      (when (member isearch-lazy-highlight-timer timer-idle-list)
        (apply (timer--function isearch-lazy-highlight-timer)
               (timer--args isearch-lazy-highlight-timer)))
      (when (member (bound-and-true-p anzu--update-timer) timer-idle-list)
        (apply (timer--function anzu--update-timer)
               (timer--args anzu--update-timer)))
      (when (member (bound-and-true-p evil--ex-search-update-timer)
                    timer-idle-list)
        (apply (timer--function evil--ex-search-update-timer)
               (timer--args evil--ex-search-update-timer))))))

(use-package! corfu-auto
  :defer t
  :config
  (setq corfu-auto-delay 0.24
        corfu-auto-prefix 2)
  (add-to-list 'corfu-auto-commands #'lispy-colon)

  ;; Modifying the buffer while in replace mode can be janky.
  (add-to-list '+corfu-inhibit-auto-functions #'evil-replace-state-p)

  ;; HACK: Augments Corfu to respect `+corfu-inhibit-auto-functions'.
  (defadvice! +corfu--post-command-a (fn &rest args)
    "Refresh Corfu after last command."
    :around #'corfu--popup-support-p
    (let ((corfu-auto
           (if corfu-auto
               (not (run-hook-with-args-until-success '+corfu-inhibit-auto-functions)))))
      (apply fn args))))


(use-package! cape
  :defer t
  :init
  (add-hook! 'prog-mode-hook
    (defun +corfu-add-cape-file-h ()
      (add-hook 'completion-at-point-functions #'cape-file -10 t)))
  (add-hook! '(org-mode-hook markdown-ts-mode-hook)
    (defun +corfu-add-cape-elisp-block-h ()
      (add-hook 'completion-at-point-functions #'cape-elisp-block 0 t)))
  ;; Make these capfs composable.
  (advice-add #'lsp-completion-at-point :around #'cape-wrap-noninterruptible)
  (advice-add #'lsp-completion-at-point :around #'cape-wrap-nonexclusive)
  (advice-add #'comint-completion-at-point :around #'cape-wrap-nonexclusive)
  (advice-add #'eglot-completion-at-point :around #'cape-wrap-nonexclusive)
  (advice-add #'pcomplete-completions-at-point :around #'cape-wrap-nonexclusive))


;;
;;; Extensions

(use-package! corfu-history
  :hook ((corfu-mode . corfu-history-mode))
  :config
  (after! savehist (add-to-list 'savehist-additional-variables 'corfu-history)))

(use-package! corfu-popupinfo
  :hook ((corfu-mode . corfu-popupinfo-mode))
  :config
  (setq corfu-popupinfo-delay '(0.5 . 1.0)))

(use-package! nerd-icons-corfu
  :defer t
  :init
  (after! corfu
    (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)))
