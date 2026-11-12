;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; lang/java/doctor.el

(assert! (fboundp 'java-ts-mode)
         "Can't find `java-ts-mode'; Emacs 29.1+ is required")

(unless (executable-find "javac")
  (warn! "Couldn't find the javac executable, are you sure the JDK is installed?"))
