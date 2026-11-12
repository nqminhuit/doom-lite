;;; minh/eglot/config.el -*- lexical-binding: t; -*-

;; No `with-eval-after-load' on `prog-mode' here: prog-mode is preloaded
;; into Emacs, so the wrapper ran immediately and only looked like
;; deferral.  `add-hook' on a mode hook is already lazy.
(add-hook! python-ts-mode #'eglot-ensure)
(add-hook! 'java-mode-hook #'eglot-ensure)
(add-hook! 'go-mode-hook #'eglot-ensure)
(add-hook! go-ts-mode #'eglot-ensure)
(add-hook! js-ts-mode #'eglot-ensure)
(add-hook! java-ts-mode #'eglot-ensure)
;; (add-hook! 'java-mode-hook #'eglot-ensure #'flymake-mode)
;; (add-hook! 'go-mode-hook #'eglot-ensure #'flymake-mode)
;; (add-hook! typescript-ts-mode #'eglot-ensure)

(with-eval-after-load 'eglot
  ;; Eglot `put's its own `flymake-overlay-control' straight onto `eglot-error' &
  ;; co, and `flymake--lookup-type-property' stops at the type's own plist -- so
  ;; the `before-string' suppression set on the `flymake-error'/`-warning'/`-note'
  ;; categories in config.el is never consulted for LSP diagnostics.  Repeat it
  ;; here (after eglot's own top-level `put') to keep the "!" indicator from
  ;; being drawn inline in the buffer text.
  (dolist (type '(eglot-error eglot-warning eglot-note))
    (setf (alist-get 'before-string (get type 'flymake-overlay-control)) nil))

  (setq eglot-diagnostics-map nil
        eglot-code-action-indicator nil
        eglot-code-action-indications nil
        eglot-extend-to-xref t
        eglot-autoshutdown t
        eglot-sync-connect 0
        eglot-events-buffer-config '(:size 0 :format short)
        jsonrpc-event-hook nil
        eglot-ignored-server-capabilities '(:hoverProvider ; no auto popup document in minibuffer
                                            :semanticTokensProvider
                                            :documentLinkProvider
                                            :documentOnTypeFormattingProvider
                                            :documentHighlightProvider
                                            :codeLensProvider
                                            :colorProvider
                                            :inlayHintProvider
                                            :foldingRangeProvider)))
