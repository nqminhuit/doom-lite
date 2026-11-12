;; -*- no-byte-compile: t; -*-
;;; checkers/syntax/packages.el

(package! flymake :built-in t)
(package! flymake-popon
  :recipe (:host github :repo "doomelpa/flymake-popon")
  :pin "99ea813346f3edef7220d8f4faeed2ec69af6060")
