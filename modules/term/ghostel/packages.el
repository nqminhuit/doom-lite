;; -*- no-byte-compile: t; -*-
;;; term/ghostel/packages.el

(package! ghostel
  :recipe (:host github :repo "dakra/ghostel"
           :files (:defaults "etc" "src" "vendor" "build.zig" "build.zig.zon" "symbols.map"))
  :pin "13da6daae61b8bdf203fd2110be01ca5fa1b041f")

(package! evil-ghostel
  :recipe (:host github :repo "dakra/ghostel"
           :files ("extensions/evil-ghostel/*.el"))
  :pin "13da6daae61b8bdf203fd2110be01ca5fa1b041f")
