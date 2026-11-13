;; -*- no-byte-compile: t; -*-
;;; completion/corfu/packages.el

(package! corfu
  :recipe (:host github :repo "minad/corfu" :files (:defaults "extensions/corfu-*.el"))
  :pin "c68f993d2df82bfab8a973c6f1af047dc3543093")
(package! cape
  :recipe (:host github :repo "minad/cape")
  :pin "f0135abaf95a22b9fb2c951751a5d0733ce61bbd")
(package! nerd-icons-corfu
  :recipe (:host github :repo "LuigiPiucco/nerd-icons-corfu")
  :pin "e1197d6c1db673f4ec7ee20cb2c4297f479420e7")
