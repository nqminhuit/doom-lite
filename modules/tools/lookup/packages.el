;; -*- no-byte-compile: t; -*-
;;; tools/lookup/packages.el

(package! dumb-jump :pin "cf06b4ccdce6a39346c32f05139f9ee8b77ee229")

;; For dictionary and online lookup
(package! request :pin "c22e3c23a6dd90f64be536e176ea0ed6113a5ba6")

(when (modulep! +docsets)
  (package! dash-docs :pin "29848b6b347ac520f7646c200ed2ec36cea3feda")
  (when (modulep! :completion vertico)
    (package! consult-dash :pin "edb57bf8cdbef422b88667fadc83e1bb046957a6"))
  (when (modulep! :completion helm)
    (package! helm-dash :pin "7f853bd34da666f0e9a883011c80f451b06f6c59"))
  (when (modulep! :completion ivy)
    (package! counsel-dash :pin "8decb980f111ebe7027361ee252279a9076da261")))
