;;; modules/doom/packages.el -*- lexical-binding: t; no-byte-compile: t; -*-

;; doom.el
(package! compat :built-in t)  ; Emacs 31's compat.el satisfies (compat "31")

;; doom-packages.el
(package! straight
  :type 'core
  :recipe `(:host github
            :repo "radian-software/straight.el"
            :branch "develop"
            :local-repo "straight.el"
            :files ("straight*.el"))
  :pin "1a6b4b29815ffa95d3545f65d32e5b3820e4e563")

;; doom-ui.el
(package! nerd-icons
  :recipe (:host github :repo "rainstormstudio/nerd-icons.el" :files (:defaults "data"))
  :pin "17faac7977242b470732efd417d3bcc8eb5a830e")

;; doom-projects.el
(package! project :built-in t)

;; Built into Emacs 31; declared so straight doesn't pull ELPA copies as deps.
(package! eldoc :built-in t)
(package! seq :built-in t)
(package! external-completion :built-in t)

;; doom-keybinds.el
(package! which-key
  :recipe (:host github :repo "emacs-straight/which-key")
  :pin "78bf634e98ff989df3d86bceffe99b3278e32b12"
  :built-in 'prefer)
