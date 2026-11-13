;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; lang/go/doctor.el

(assert! (fboundp 'go-ts-mode)
         "Can't find `go-ts-mode'; Emacs 31.1+ is required")

(unless (executable-find "gotests")
  (warn! "Couldn't find gotests. Generating tests will not work"))


(unless (executable-find "gopls")
  (warn! "Couldn't find gopls."))
