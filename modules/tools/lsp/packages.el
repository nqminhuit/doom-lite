;; -*- no-byte-compile: t; -*-
;;; tools/lsp/packages.el

(if (modulep! +eglot)
    (progn
      (package! eglot :built-in t)
      (package! jsonrpc :built-in t)
      (package! xref :built-in t)
      (when (modulep! :completion vertico)
        (package! consult-eglot :pin "3e4d9a40911b897c0a2c5d20199d0f7c30bfc1c2")))

  ;; lsp-mode must be rebuilt if this variable is changed, so expose it here so
  ;; users can change it from $DOOMDIR/packages.el.
  (eval-and-compile (defvar lsp-use-plists t))

  (package! lsp-mode
    :pin "5f36bd4da7bef0a01e9d067f992ea4c4ac9c7314"
    :env `(("LSP_USE_PLISTS" . ,(and lsp-use-plists "1"))))
  (package! lsp-ui :pin "176eca71d1c5498ed6258b5b27d73293ff7cd7ed")
  (when (modulep! :completion ivy)
    (package! lsp-ivy :pin "b061ff4afdcf3bac606fb46be84d67b03d24cfcc"))
  (when (modulep! :completion helm)
    (package! helm-lsp :pin "a005e935d537484c5afbaaf0ea6ddc7f429242dd"))
  (when (modulep! :completion vertico)
    (package! consult-lsp :pin "f41a3946987a3880068f95f3725bbb7b0d4b0b22")))
