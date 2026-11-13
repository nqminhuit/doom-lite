;;; lang/markdown/config.el -*- lexical-binding: t; -*-

;; Not autoloaded in 31.1, and no markdown-mode left to claim these files.
(use-package! markdown-ts-mode
  :mode ("\\.\\(?:md\\|markdown\\|mkd\\|mdown\\|mkdn\\|mdwn\\)\\'" . markdown-ts-mode)
  :mode ("/README\\'" . markdown-ts-mode))
