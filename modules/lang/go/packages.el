;; -*- no-byte-compile: t; -*-
;;; lang/go/packages.el

(package! go-gen-test
  :recipe (:host github :repo "s-kostyaev/go-gen-test" :files ("go-gen-test.el"))
  :pin "af00a9abbaba2068502327ecdef574fd894a884b")
