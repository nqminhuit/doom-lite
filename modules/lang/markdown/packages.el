;; -*- no-byte-compile: t; -*-
;;; lang/markdown/packages.el

(package! markdown-mode :pin "76cb4ffecfdf95ee769e5cb4608e04202c3c1521")
(package! markdown-toc :pin "ab4ba86e627ef83b7eec6706d66b81241c96f48c")

;; Required by `markdown-mode', or it will install it via package.el if it isn't
;; present when you call `markdown-edit-code-block'.
(package! edit-indirect :pin "82a28d8a85277cfe453af464603ea330eae41c05")

(package! evil-markdown
  :recipe (:host github :repo "Somelauw/evil-markdown")
  :pin "8e6cc68af83914b2fa9fd3a3b8472573dbcef477")
