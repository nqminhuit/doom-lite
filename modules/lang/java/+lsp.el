;;; lang/java/+lsp.el -*- lexical-binding: t; -*-
;;;###if (and (modulep! +lsp) (modulep! :tools lsp -eglot))

(use-package! lsp-java
  :defer t
  :preface
  (setq lsp-java-workspace-dir (doom-profile-data-dir t "java-workspace"))
  (add-hook 'java-mode-local-vars-hook #'lsp! 'append)
  (add-hook 'java-ts-mode-local-vars-hook #'lsp! 'append))
