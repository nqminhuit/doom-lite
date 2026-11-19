;; -*- no-byte-compile: t; -*-
;;; editor/evil/packages.el

(package! evil
  :recipe (:host github :repo "emacs-evil/evil" :files (:defaults (:exclude "evil-test-helpers.el")))
  :pin "76e094309f615594ced89afa7b32c2051715b402")
;; goto-chg: dependency of evil
(package! goto-chg
  :recipe (:host github :repo "emacs-evil/goto-chg")
  :pin "72f556524b88e9d30dc7fc5b0dc32078c166fda7")
(package! evil-args
  :recipe (:host github :repo "wcsmith/evil-args")
  :pin "a8151556f63c9d45d0c44c8a7ef9e5a542f3cdc7")
(package! evil-embrace :pin "3081d37811b6a3dfaaf01d578c7ab7a746c6064d")
(package! evil-escape
  :recipe (:host github :repo "hlissner/evil-escape")
  :pin "819f1ee1cf3f69a1ae920e6004f2c0baeebbe077")
(package! evil-exchange
  :recipe (:host github :repo "Dewdrops/evil-exchange")
  :pin "5f0a2d41434c17c6fb02e4f744043775de1c63a2")
(package! evil-indent-plus
  :recipe (:host github :repo "TheBB/evil-indent-plus")
  :pin "f392696e4813f1d3a92c7eeed333248914ba6dae")
(package! evil-lion :pin "5a0bca151466960e090d1803c4c5ded88875f90a")
(package! evil-numbers
  ;; REVIEW: Don't byte-compile until juliapath/evil-numbers#30 is addressed.
  :recipe (:host github :repo "juliapath/evil-numbers" :compile nil)
  :pin "616aff9e5cee012954756ed2715209fa90308cdf")
(package! evil-snipe :pin "16317d7e54313490a0fe8642ed9a1a72498e7ad2")
;; shift-number: dependency of evil-numbers
(package! shift-number
  :recipe (:host codeberg :repo "ideasman42/emacs-shift-number")
  :pin "52f4d32080cca50da0f88b2141d597827c7341cf")
(package! evil-surround
  :recipe (:host github :repo "emacs-evil/evil-surround")
  :pin "e6548372e8359ee55e67d73ca418314086011f1a")
(package! evil-textobj-anyblock
  :recipe (:host github
           :repo "willghatch/evil-textobj-anyblock"
           :branch "fix-inner-block")
  :pin "29280cd71a05429364cdceef2ff595ae8afade4d")
(package! evil-traces
  :recipe (:host github :repo "mamapanda/evil-traces")
  :pin "82e8a7b4213aed140f6eb5f2cc33a09bb5587166")
(package! evil-visualstar
  :recipe (:host github :repo "bling/evil-visualstar")
  :pin "2b804e317700896116e88ae751df4a36ac8c3934")
(package! exato :pin "aee7af7b7a0e7551478f453d1de7d5b9cb2e06c4")
(package! evil-quick-diff
  :recipe (:host github :repo "rgrinberg/evil-quick-diff")
  :pin "69c883720b30a892c63bc89f49d4f0e8b8028908")

(package! evil-collection
  :recipe (:host github :repo "emacs-evil/evil-collection" :files (:defaults "modes"))
  :pin "e3f70c513585086ad83e245829e1de8f72f2de26")
