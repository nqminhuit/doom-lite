;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; Declare packages here and run 'doom sync'. Every package needs a `:recipe'
;; (`:host', `:repo', optional `:files') and a full-SHA `:pin'; bump a package
;; by editing its `:pin'. Disable a module's package with `:disable t'.

(package! groovy-mode :disable t)
(package! android-mode :disable t)
(package! marginalia :disable t)
(package! nodejs-repl :disable t)
(package! evil-lion :disable t)
(package! evil-embrace :disable t)
(package! exato :disable t) ;; evil xml text object, no need for now.
(package! evil-snipe :disable t);; experiment 10:59:33 2025-05-20
(package! flymake-popon :disable t)

(package! pulsar :recipe (:host github :repo "protesilaos/pulsar")
  :pin "83d53271a0ec2728ef36b45704d47bafd170e814")
(package! ecoin :recipe (:host github :repo "nqminhuit/ecoin")
  :pin "086ad6a2806466e8f8c09f8c217aec992092678b")
(package! gemit :recipe (:host github :repo "nqminhuit/gemit")
  :pin "1291108abbb1945884941d3f928f718485dcb29f")
(package! s3-manager :recipe (:host github :repo "nqminhuit/s3-manager.el")
  :pin "5abb3df5385138edc4d24d331700121b6e329527")
;; (package! ecim :recipe (:host github :repo "nqminhuit/ecim"))
(package! podel :recipe (:host github :repo "nqminhuit/podel")
  :pin "42e3db2078ab7dd3fadada2e3d84db89c7607bb8")

;; (package! capf-autosuggest)
