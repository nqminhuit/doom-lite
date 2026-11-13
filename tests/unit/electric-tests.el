;;; electric-tests.el --- electric-pair setup -*- lexical-binding: t; -*-

(require 'ert)

(defconst et--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defun et--path (rel) (expand-file-name rel et--root))

(defvar doom-first-buffer-hook nil)
(load (et--path "lisp/doom-lib.el") nil t)
(unless (fboundp 'modulep!) (defmacro modulep! (&rest _) nil))
(unless (fboundp 'use-package!) (defmacro use-package! (&rest _) nil))
(load (et--path "modules/emacs/electric/autoload.el") nil t)
(load (et--path "modules/emacs/electric/config.el") nil t)

(ert-deftest electric/first-buffer-enables-pairing ()
  (unwind-protect
      (progn
        (run-hooks 'doom-first-buffer-hook)
        (should electric-pair-mode)
        (with-temp-buffer
          (emacs-lisp-mode)
          (let ((last-command-event ?\())
            (self-insert-command 1))
          (should (equal (buffer-string) "()"))))
    (electric-pair-mode -1)))

(ert-deftest electric/minibuffer-pairing ()
  (unwind-protect
      (progn
        (electric-pair-mode 1)
        (dolist (cmd '(execute-extended-command evil-ex))
          (with-temp-buffer
            (let ((this-command cmd))
              (+electric-pair-minibuffer-h))
            (should (eq (and electric-pair-mode t) (eq cmd 'evil-ex))))))
    (electric-pair-mode -1)))

(ert-deftest electric/minibuffer-eval-expression-order ()
  (unwind-protect
      (progn
        (electric-pair-mode 1)
        (with-temp-buffer
          (let ((this-command 'pp-eval-expression))
            (+electric-pair-minibuffer-h))
          (should-not electric-pair-mode)
          (+electric-pair-eval-expression-h)
          (should electric-pair-mode)))
    (electric-pair-mode -1)))

(ert-deftest electric/minibuffer-hook-registration ()
  (let ((minibuffer-setup-hook nil)
        (eval-expression-minibuffer-setup-hook nil))
    (load (et--path "modules/emacs/electric/config.el") nil t)
    (add-hook 'minibuffer-setup-hook #'ignore)
    (should (< (seq-position minibuffer-setup-hook #'+electric-pair-minibuffer-h)
               (seq-position minibuffer-setup-hook #'ignore)))
    (should (memq #'+electric-pair-eval-expression-h
                  eval-expression-minibuffer-setup-hook))))

(ert-deftest electric/minibuffer-hooks-respect-global-off ()
  (electric-pair-mode -1)
  (with-temp-buffer
    (let ((this-command 'evil-ex))
      (+electric-pair-minibuffer-h))
    (should-not electric-pair-mode)
    (+electric-pair-eval-expression-h)
    (should-not electric-pair-mode)))

;;; electric-tests.el ends here
