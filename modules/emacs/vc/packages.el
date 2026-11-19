;; -*- no-byte-compile: t; -*-
;;; emacs/vc/packages.el

(package! vc :built-in t)
(package! vc-annotate :built-in t)
(package! smerge-mode :built-in t)

(package! git-modes
  :recipe (:host github :repo "magit/git-modes")
  :pin "f8a453725586c8225e47afca4c8cbc2c5585bf33")
