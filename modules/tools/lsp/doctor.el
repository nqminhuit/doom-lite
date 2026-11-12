;;; tools/lsp/doctor.el -*- lexical-binding: t; -*-

(unless (modulep! +eglot)
  (unless (executable-find "npm")
    (warn! "Couldn't find npm. `lsp-mode' needs npm to auto-install some LSP servers. For more information, see https://emacs-lsp.github.io/lsp-mode/page/languages/.")))
