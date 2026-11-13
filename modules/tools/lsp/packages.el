;; -*- no-byte-compile: t; -*-
;;; tools/lsp/packages.el

(package! eglot :built-in t)
(package! jsonrpc :built-in t)
(package! xref :built-in t)
(package! consult-eglot
  :recipe (:host github :repo "mohkale/consult-eglot")
  :pin "3e4d9a40911b897c0a2c5d20199d0f7c30bfc1c2")
