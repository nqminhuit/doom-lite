;; -*- no-byte-compile: t; -*-
;;; term/ghostel/packages.el

(package! ghostel
  :recipe (:host github :repo "dakra/ghostel"
           :files (:defaults "etc" "src" "vendor" "build.zig" "build.zig.zon" "symbols.map"))
  :pin "4af9560818534dd97902f045acd0f9e44fb14525")

(package! evil-ghostel
  :recipe (:host github :repo "dakra/ghostel"
           :files ("extensions/evil-ghostel/*.el"))
  :pin "4af9560818534dd97902f045acd0f9e44fb14525")
