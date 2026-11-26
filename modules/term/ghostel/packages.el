;; -*- no-byte-compile: t; -*-
;;; term/ghostel/packages.el

(package! ghostel
  :recipe (:host github :repo "dakra/ghostel"
           :files (:defaults "etc" "src" "vendor" "build.zig" "build.zig.zon" "symbols.map"))
  :pin "2945fb6b6d63e960e61a1e40f3543300077c21c8")

(package! evil-ghostel
  :recipe (:host github :repo "dakra/ghostel"
           :files ("extensions/evil-ghostel/*.el"))
  :pin "2945fb6b6d63e960e61a1e40f3543300077c21c8")
