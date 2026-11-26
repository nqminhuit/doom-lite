;;; modules/doom/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

;; doom.el
(package! compat :built-in t)  ; Emacs 31's compat.el satisfies (compat "31")

;; doom-ui.el
(package! nerd-icons
  :recipe (:host github :repo "rainstormstudio/nerd-icons.el" :files (:defaults "data"))
  :pin "760ea462e5edd431ec530e4d3a6abb7a4e05f95b")

;; doom-projects.el
(package! project :built-in t)

;; Built into Emacs 31; declared so dependencies on them resolve to Emacs's copies.
(package! eldoc :built-in t)
(package! seq :built-in t)
(package! external-completion :built-in t)

;; doom-keybinds.el
(package! which-key
  :recipe (:host github :repo "emacs-straight/which-key")
  :pin "78bf634e98ff989df3d86bceffe99b3278e32b12"
  :built-in 'prefer)
