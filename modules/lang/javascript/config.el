;;; lang/javascript/config.el -*- lexical-binding: t; -*-


;;
;;; Major modes

(defun +javascript-common-config (mode)
  (add-hook (intern (format "%s-local-vars-hook" mode)) #'lsp! 'append)

  (when (memq mode '(typescript-mode typescript-ts-mode))
    (set-electric! mode :chars '(?\} ?\)) :words '("||" "&&"))))


(use-package! js
  :mode ("\\.[mc]?js\\'" . js-mode)
  :mode ("\\.es6\\'" . js-mode)
  :mode ("\\.pac\\'" . js-mode)
  :init
  (set-tree-sitter! 'js-mode 'js-ts-mode '(javascript jsdoc))
  :config
  (+javascript-common-config 'js-mode)
  (+javascript-common-config 'js-ts-mode)

  (setq js-chain-indent t))


(use-package! typescript-ts-mode  ; 29.1+ only
  :mode "\\.[cm]?ts\\'"
  :mode ("\\.[tj]sx\\'" . tsx-ts-mode)
  :init
  (set-tree-sitter! 'typescript-mode 'typescript-ts-mode 'typescript)
  (set-tree-sitter! nil 'tsx-ts-mode 'tsx)
  :config
  (+javascript-common-config 'typescript-ts-mode)
  (+javascript-common-config 'tsx-ts-mode))


;;
;;; Extensions

;; Parse node stack traces in the compilation buffer
(after! compilation
  (add-to-list 'compilation-error-regexp-alist 'node)
  (add-to-list 'compilation-error-regexp-alist-alist
               '(node "^[[:blank:]]*at \\(.*(\\|\\)\\(.+?\\):\\([[:digit:]]+\\):\\([[:digit:]]+\\)"
                 2 3 4)))


;;
;;; Projects

(def-project-mode! +javascript-npm-mode
  :modes '(html-mode
           css-mode
           web-mode
           markdown-ts-mode
           js-mode  ; includes js2-mode and rjsx-mode
           js-ts-mode
           json-ts-mode
           typescript-mode
           typescript-ts-mode
           tsx-ts-mode
           solidity-mode)
  :when (locate-dominating-file default-directory "package.json")
  :add-hooks '(+javascript-add-npm-path-h))

(def-project-mode! +javascript-gulp-mode
  :when (locate-dominating-file default-directory "gulpfile.js"))
