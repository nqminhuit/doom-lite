;;; modules/doom/init.el -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;;
;;; * Extra file extensions to support

(add-to-list 'auto-mode-alist '("/LICENSE\\'" . text-mode))
(add-to-list 'auto-mode-alist '("rc\\'" . conf-mode) 'append)

;; Support for Doom dotfiles
(add-to-list 'auto-mode-alist '("/\\.doom\\(?:modules?\\|profiles?\\)?\\'" . lisp-data-mode))


;;
;;; * 3rd Party Packages

(use-package! nerd-icons
  :commands (nerd-icons-octicon
             nerd-icons-faicon
             nerd-icons-flicon
             nerd-icons-wicon
             nerd-icons-mdicon
             nerd-icons-codicon
             nerd-icons-devicon
             nerd-icons-ipsicon
             nerd-icons-pomicon
             nerd-icons-powerline))


;; lisp/doom-emacs.el unconditionally expects which-key to be present because
;; that's too early in the startup process to check for autoloads (plus,
;; which-key is a built-in package after 30.1). This is here in case the user
;; has disabled which-key (or this module).
(unless (fboundp 'which-key-mode)
  (remove-hook 'doom-first-input-hook #'which-key-mode))

;;; init.el ends here
