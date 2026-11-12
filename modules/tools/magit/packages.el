;; -*- no-byte-compile: t; -*-
;;; tools/magit/packages.el

;; REVIEW: This file contains pinned dependencies. This goes against our policy
;;   of only pinning primary packages, but an exception is made because the
;;   Magit ecosystem seems prone to breakage.

(package! transient :built-in t) ; Emacs 31.1 ships 0.13.3; magit needs 0.13
(package! cond-let :pin "09292a77001434f59ab55c775dec2b98cb18d028")  ; 1.1.5

(package! magit :pin "659f89955cf60fe3d4326d881c412df06c69680d")     ; 4.7.1
