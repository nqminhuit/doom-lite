;; -*- no-byte-compile: t; -*-
;;; completion/corfu/packages.el

(package! corfu
  :recipe (:host github :repo "minad/corfu" :files (:defaults "extensions/corfu-*.el"))
  :pin "15fed49c97bf6b2436641714ae15bbd2f3e37b77")
(package! cape
  :recipe (:host github :repo "minad/cape")
  :pin "50bc6187daf9af9df1a802fcbbd91fe4b952fc69")
(package! nerd-icons-corfu
  :recipe (:host github :repo "LuigiPiucco/nerd-icons-corfu")
  :pin "9b089b31a810328d9b740b35a19eb796eb7a2d8a")
