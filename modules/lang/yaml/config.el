;;; lang/yaml/config.el -*- lexical-binding: t; -*-

(use-package! yaml-mode
  :mode "Procfile\\'"
  :init
  ;; HACK: `yaml-ts-mode' doesn't implement any indentation (falling back to
  ;;   `indent-relative'), so borrow `yaml-mode's. See
  ;;   https://debbugs.gnu.org/cgi/bugreport.cgi?bug=77094.
  (setq-hook! 'yaml-ts-mode-hook indent-line-function #'yaml-indent-line)
  :commands yaml-indent-line)


(use-package! yaml-ts-mode  ; 29.1+ only
  :defer t
  :init
  (set-tree-sitter! 'yaml-mode 'yaml-ts-mode 'yaml))
