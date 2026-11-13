;;; modules/doom/compat/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

;; TODO: Mirror these packages on doomelpa, to "immortalize" this module and
;;   make Doom core resistant to upstream breakage.

(package! auto-minor-mode :pin "17cfa1b54800fdef2975c0c0531dad34846a5065")
(package! use-package
  :built-in 'prefer
  :pin "4b3484b550431f74ab9cda060a8dc983fe482131")

