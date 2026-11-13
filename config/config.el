;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

(global-ecoin-mode 1)
(setq ecoin-llama-url "http://127.0.0.1:11882"
      ecoin-llama-api-key "~/.llama-key"
      ecoin-llama-model "Seed-Coder-8B-Base.Q4_K_M.gguf"
      ecoin-fallback-backend 'copilot)

(setopt gemit-local-url "http://127.0.0.1:11881"
        gemit-local-api-key "~/.llama-key"
        gemit-local-model "gemma-4-E4B-it-Q8_0.gguf"
        gemit-model "gemini-flash-lite-latest")

(with-eval-after-load 'magit (gemit-install))

(with-eval-after-load 'evil
  (setq +evil-want-o/O-to-continue-comments nil)
  (evil-set-initial-state 'shell-mode 'normal)
  ;; `evil-change-without-register' is defined in minh/utils/config.el, also
  ;; behind `with-eval-after-load 'evil'.  `define-key' only stores the symbol,
  ;; so whichever of the two after-load forms runs first is irrelevant.
  (define-key evil-normal-state-map (kbd "c") #'evil-change-without-register)
  (define-key evil-visual-state-map (kbd "c") #'evil-change-without-register))

(with-eval-after-load 'vertico
  (setq
   vertico-count 10
   vertico-cycle nil
   read-file-name-completion-ignore-case t
   read-buffer-completion-ignore-case t
   completion-ignore-case t)

  ;; vertico: prefix current candidate with arrow
  (defvar +vertico-current-arrow t)
  (cl-defmethod vertico--format-candidate :around
    (cand prefix suffix index start &context ((and +vertico-current-arrow
                                                   (not (bound-and-true-p vertico-flat-mode)))
                                              (eql t)))
    (setq cand (cl-call-next-method cand prefix suffix index start))
    (if (bound-and-true-p vertico-grid-mode)
        (if (= vertico--index index)
            (concat #(">" 0 1 (face vertico-current)) cand)
          (concat #("_" 0 1 (display " ")) cand))
      (if (= vertico--index index)
          (concat
           #(" " 0 1 (display (left-fringe right-triangle vertico-current)))
           cand)
        cand))))

(with-eval-after-load 'sh-script (add-hook 'sh-mode-hook #'outline-minor-mode))

(with-eval-after-load 'eshell
  ;; NOTE no `capf-autosuggest-mode' hook here: the package is not installed
  ;; (see packages.el), and a hook entry for a void function makes
  ;; `run-mode-hooks' signal, which aborts `eshell-mode' half-initialised and
  ;; skips every hook registered after it.
  (setq
   eshell-hist-ignoredups t
   eshell-history-size 5000
   eshell-buffer-maximum-lines 5000
   eshell-scroll-to-bottom-on-input t
   eshell-aliases-file "/opt/minh/linux-config/configs/dotfiles/emacs/aliases"))

(with-eval-after-load 'flymake
  ;; Diagnostics are already counted on the modeline (see modules/minh/modeline),
  ;; so no fringe, margin or inline indicator is wanted.  Setting
  ;; `flymake-indicator-type' and the two *-indicator-position options to nil is
  ;; not enough: since flymake 1.4.1 `flymake--highlight-line' always sets the
  ;; overlay's `before-string' to (propertize "!" 'display SPEC), and SPEC is nil
  ;; exactly when those options are nil -- so the bare "!" gets drawn inline in
  ;; the buffer text.  `flymake-overlay-control' is applied to the overlay before
  ;; flymake's own default and an explicit nil survives, so this suppresses the
  ;; indicator outright.  Resolved through `flymake-category', this also covers
  ;; the keyword types `:error'/`:warning'/`:note' used by the built-in backends.
  ;; Eglot needs the same treatment on its own types -- see modules/minh/eglot.
  (dolist (category '(flymake-error flymake-warning flymake-note))
    (setf (alist-get 'before-string (get category 'flymake-overlay-control)) nil))
  ;; Keeps `flymake--resize-margins' from ever touching the margins.
  (setopt flymake-indicator-type nil))

;;; Hooks
(with-eval-after-load 'magit
  (setq git-commit-style-convention-checks '(non-empty-second-line))

  (add-hook! magit-section-mode
    (defun doom-disable-hl-line-h ()
      (hl-line-mode -1)
      (setq-local doom--hl-line-mode t))))

(with-eval-after-load 'nerd-icons
  (add-to-list 'nerd-icons-regexp-icon-alist '("^\\.?Containerfile" nerd-icons-sucicon "nf-seti-docker" :face nerd-icons-blue)))

(with-eval-after-load 'calendar
  (defun my/calendar-copy-date ()
    "Copy the date at point in Calendar as YYYY-MM-DD."
    (interactive)
    (pcase-let ((`(,month ,day ,year) (calendar-cursor-to-date)))
      (let ((date (format "%04d-%02d-%02d" year month day)))
        (kill-new date)
        (message "Copied date: %s" date))))
  (map! :map calendar-mode-map
        "M-w" #'my/calendar-copy-date))

;; `prog-mode' is preloaded into Emacs, so `(featurep 'prog-mode)' is already t
;; when this file runs and the `with-eval-after-load 'prog-mode' that used to
;; wrap this section evaluated its body immediately.  Left unwrapped so the
;; startup order is visible.

;; 0.5 is the Emacs default, and the delay is there to debounce.  Eglot adds
;; three functions to `eldoc-documentation-functions' -- hover, signatureHelp
;; and documentHighlight -- so one eldoc tick is three LSP requests.  Eldoc is
;; scheduled from `post-command-hook' and fires once per idle period, so at 0
;; every micro-pause while holding `j' sends another three to the server.
(setq eldoc-idle-delay 0.2)
(setq +workspaces-switch-project-function #'dired)

(set-popup-rule! "\\*Async Shell Command\\*" :side 'bottom :size 0.3 :select t :quit 'current)

(dolist (mode '((".dir-locals.el" . emacs-lisp-mode)
                ("\\.ini\\'" . conf-windows-mode)
                ("\\.env\\'" . conf-mode)
                ("Caddyfile" . conf-mode)
                ("\\(Docker\\|Container\\)file" . containerfile-mode)
                ("\\.dockerfile\\'" . containerfile-mode)
                ("\\.proto\\'" . m-proto-mode)
                ("\\.ps\\(?:1\\|m1\\|d1\\)\\'" . m-powershell-mode)
                ("\\.uc\\'" . c++-ts-mode)
                ("\\.log\\'" . prog-mode)))
  (add-to-list 'auto-mode-alist mode))

(pulsar-global-mode 1)
(editorconfig-mode 1)

(add-hook! (help-mode
            magit-mode
            shell-mode
            json-mode
            json-ts-mode
            java-mode
            java-ts-mode
            comint-mode)
           #'(lambda()
               (visual-line-mode 1)
               (setq word-wrap nil)))

(with-eval-after-load 'corfu

  ;; disable corfu in minibuffer b/c the TAB-completion of corfu is bad in minibuffer:
  (setq global-corfu-minibuffer nil)

  ;; no auto suggest, should manually trigger
  ;; NOTE this also means `corfu-auto.el' is never loaded (corfu.el only
  ;; `require's it `(when corfu-auto ...)'), so there is no point tweaking
  ;; `corfu-auto-commands' -- it lives in that file.
  (setq corfu-auto nil)

  (setq corfu-preselect 'valid
        corfu-cycle nil
        corfu-min-width 30
        corfu-preview-current nil))

(with-eval-after-load 'compile
  ;; There are 2 solutions to reconfig the error regex of maven:
  ;; Solution 1: completely remove maven from `compilation-error-regexp-alist'
  ;; remove maven error regexp from compilation error list,
  ;; I usually don't need to see the first error or warning from maven
  ;; the summary of maven is enough for me.
  ;; (delete 'maven compilation-error-regexp-alist)

  ;; Solution 2: only remove the regex WARNING from existing regex
  ;; TODO: should remove or override the existing maven regex
  ;; instead adding over it
  (add-to-list 'compilation-error-regexp-alist-alist
               '(maven "^\\(?:\\[\\(?:ERROR\\|\\(?1:INFO\\)\\)] \\)?\
\\(?2:[^\n []\\(?:[^\n :]\\| [^\n/-]\\|:[^\n []\\)*\\):\
\\[\\(?3:[[:digit:]]+\\),\\(?4:[[:digit:]]+\\)] " 2 3 4 (0 . 1)))

  (add-to-list 'compilation-mode-font-lock-keywords
               '("ERROR" (0 compilation-error-face)))
  (setq compilation-scroll-output 'first-error))

(with-eval-after-load 'ghostel
  (add-hook! ghostel-mode #'(lambda() (corfu-mode 0))) ;; disable corfu, use zsh completion instead
  (add-hook! ghostel-mode #'(lambda() (hl-line-mode -1))) ;; disable hl-line, distracting on live terminal output
  (require 'evil-ghostel)
  (add-hook 'ghostel-mode-hook #'evil-ghostel-mode))

(with-eval-after-load 'ibuffer
  (setq ibuffer-formats
        '((mark modified read-only locked " "
                (name 48 48 :left)
                " "
                (size 5 -1 :right)
                " "
                (mode 16 16 :left :elide)
                " "
                " " filename-and-process)
          (mark " " (name 16 -1) " " filename))))

;; `isearch' and `fringe' are preloaded too -- same story as `prog-mode' above.
(setq isearch-lazy-count t)

;; left fringe only
(set-fringe-mode '(nil . 0))

(with-eval-after-load 'display-line-numbers
  ;; disable line numbers to boost performance
  (setq display-line-numbers-type nil))

(with-eval-after-load 'dictionary
  (setq  dictionary-server "dict.org"))

(with-eval-after-load 'calc (add-hook! calc-mode #'(lambda () (setq calc-algebraic-mode t))))

(with-eval-after-load 'dired
  (setopt dired-listing-switches "-alh")
  (setopt dired-dwim-target t)
  (setopt dired-guess-shell-alist-user '(("\\.mp3\\'" "mpv")
                                         ("\\.mp4\\'" "mpv"))))

(with-eval-after-load 'dired-aux
  (setq dired-compress-directory-default-suffix ".zip")
  (setq dired-compress-files-alist '(("\\.zip\\'" . "zip %o -r --filesync %i"))))

;; Completely blacklist the Go module cache
(with-eval-after-load 'project
  (add-to-list 'project-list-exclude
               (lambda (pr)
                 (string-prefix-p (expand-file-name "~/go/pkg/mod")
                                  (expand-file-name (project-root pr))))))

(with-eval-after-load 'org
  (setopt org-startup-folded 'fold))

(with-eval-after-load 'jinx
  (dolist (hook '(text-mode-hook prog-mode-hook conf-mode-hook))
    (add-hook hook #'jinx-mode)))

(define-key! :keymaps +default-minibuffer-maps
  "C-r"    #'(lambda ()
               (interactive)
               (evil-delete-back-to-indentation)
               (consult-history)))

;; (setq shell-command-prompt-show-cwd t)

(add-to-list 'warning-suppress-types '(yasnippet backquote-change))
(add-to-list 'warning-suppress-types '(eglot workspace/didChangeWorkspaceFolders))

(add-to-list 'default-frame-alist '(fullscreen . maximized))
(mouse-avoidance-mode 'banish)
