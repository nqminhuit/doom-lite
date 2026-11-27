;; -*- no-byte-compile: t; -*-
;;; term/ghostel/packages.el

(package! ghostel
  :recipe (:host github :repo "dakra/ghostel"
           :files (:defaults "etc" "src" "vendor" "build.zig" "build.zig.zon" "symbols.map"))
  :pin "87c8b8c6c3791482471d17eedb4927900182994d")

(package! evil-ghostel
  :recipe (:host github :repo "dakra/ghostel"
           :files ("extensions/evil-ghostel/*.el"))
  :pin "87c8b8c6c3791482471d17eedb4927900182994d")
