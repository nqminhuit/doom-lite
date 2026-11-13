;;; lang/json/config.el -*- lexical-binding: t; -*-

;; Explicit entries: no json-mode left to claim these files and remap to the ts mode.
(use-package! json-ts-mode
  :mode ("\\.js\\(?:on\\|[hl]int\\(?:rc\\)?\\)\\'" . json-ts-mode)
  :mode ("\\.jsonc\\'" . json-ts-mode)
  :config
  (set-electric! 'json-ts-mode :chars '(?\n ?: ?{ ?})))
