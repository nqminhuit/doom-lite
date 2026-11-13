;;; keybinds-tests.el --- map!/define-key! behavior -*- lexical-binding: t; -*-

(require 'ert)

(defconst kbt--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defun kbt--path (rel) (expand-file-name rel kbt--root))

(load (kbt--path "tests/packages-paths.el") nil t)

(dolist (pkg '("evil" "goto-chg" "general"))
  (let ((dir (tpp-build-dir kbt--root pkg)))
    (when (file-directory-p dir) (add-to-list 'load-path dir))))

(defvar doom-after-init-hook nil)
(defvar doom-after-modules-init-hook nil)
(load (kbt--path "lisp/doom-lib.el") nil t)
(unless (fboundp 'modulep!) (defmacro modulep! (&rest _) nil))

(defconst kbt--evil-p (require 'evil nil t))
(if kbt--evil-p
    (load (kbt--path "modules/doom/compat/+keybinds.el") nil t)
  (message "keybinds-tests: evil not found, skipping"))

(defvar kbt-map nil)
(defvar kbt-map2 nil)
(defvar kbt-map3 nil)
(defvar kbt-maps-var nil)
(defvar kbt-later-map nil)

(defmacro kbt--eval (&rest body)
  "Eval BODY with `noninteractive' nil so `map!' actually expands."
  `(let ((noninteractive nil)) (eval '(progn ,@body) t)))

(defun kbt--fresh ()
  (setq kbt-map (make-sparse-keymap)
        kbt-map2 (make-sparse-keymap)
        kbt-map3 (make-sparse-keymap)
        kbt-maps-var '(kbt-map kbt-map2)))

(defun kbt--lookup (map key)
  (lookup-key map (if (stringp key) (kbd key) key)))

(defun kbt--state-lookup (state map key)
  (kbt--lookup (evil-get-auxiliary-keymap map state) key))

(defun kbt--label (map key)
  (require 'which-key)
  (cdr (assoc key (which-key--get-keymap-bindings map))))

(defun kbt--label-p (map key regexp)
  (let ((l (kbt--label map key)))
    (and (stringp l) (string-match-p regexp l))))

(defmacro kbt--test (name &rest body)
  (declare (indent 1))
  `(ert-deftest ,(intern (format "keybinds/%s" name)) ()
     (skip-unless kbt--evil-p)
     (kbt--fresh)
     ,@body))

(defun kbt-inner () (interactive))
(defun kbt-outer () (interactive))
(defun kbt-over () (interactive))
(defun kbt-local () (interactive))
(defun kbt-leader-cmd () (interactive))
(defun kbt-local-cmd () (interactive))
(defun kbt-cmd () (interactive))

;;; map! basics

(kbt--test map-plain
  (kbt--eval (map! :map kbt-map "a" #'forward-char))
  (should (eq (kbt--lookup kbt-map "a") #'forward-char))
  (kbt--eval (map! :map (kbt-map kbt-map2) "b" #'ignore))
  (should (eq (kbt--lookup kbt-map "b") #'ignore))
  (should (eq (kbt--lookup kbt-map2 "b") #'ignore)))

(kbt--test states-single
  (kbt--eval (map! :map kbt-map
                   :n "a" #'ignore :i "b" #'ignore :v "c" #'ignore
                   :m "d" #'ignore :o "e" #'ignore))
  (should (eq (kbt--state-lookup 'normal kbt-map "a") #'ignore))
  (should-not (kbt--state-lookup 'insert kbt-map "a"))
  (should (eq (kbt--state-lookup 'insert kbt-map "b") #'ignore))
  (should (eq (kbt--state-lookup 'visual kbt-map "c") #'ignore))
  (should (eq (kbt--state-lookup 'motion kbt-map "d") #'ignore))
  (should (eq (kbt--state-lookup 'operator kbt-map "e") #'ignore))
  (should-not (kbt--lookup kbt-map "a")))

(kbt--test states-combined
  (kbt--eval (map! :map kbt-map :nv "a" #'ignore :g "b" #'ignore
                   :gi "c" #'ignore :gn "d" #'ignore))
  (should (eq (kbt--state-lookup 'normal kbt-map "a") #'ignore))
  (should (eq (kbt--state-lookup 'visual kbt-map "a") #'ignore))
  (should-not (kbt--state-lookup 'insert kbt-map "a"))
  (should (eq (kbt--lookup kbt-map "b") #'ignore))
  (should-not (kbt--state-lookup 'normal kbt-map "b"))
  (should (eq (kbt--lookup kbt-map "c") #'ignore))
  (should (eq (kbt--state-lookup 'insert kbt-map "c") #'ignore))
  (should (eq (kbt--lookup kbt-map "d") #'ignore))
  (should (eq (kbt--state-lookup 'normal kbt-map "d") #'ignore)))

(kbt--test default-keymap
  (unwind-protect
      (progn
        (kbt--eval (map! :n "<f35>" #'ignore))
        (should (eq (kbt--lookup evil-normal-state-map "<f35>") #'ignore))
        (should-not (kbt--lookup global-map "<f35>"))
        (kbt--eval (map! "<f34>" #'ignore))
        (should (eq (kbt--lookup global-map "<f34>") #'ignore)))
    (define-key evil-normal-state-map (kbd "<f35>") nil)
    (define-key global-map (kbd "<f34>") nil)))

;;; prefixes and labels

(kbt--test prefix
  (kbt--eval (map! :map kbt-map :prefix "x" "y" #'ignore))
  (should (eq (kbt--lookup kbt-map "x y") #'ignore))
  (kbt--eval (map! :map kbt-map (:prefix "x" (:prefix "y" "z" #'forward-char))))
  (should (eq (kbt--lookup kbt-map "x y z") #'forward-char))
  (kbt--eval (map! :map kbt-map (:prefix "p" :n "y" #'ignore)))
  (should (eq (kbt--state-lookup 'normal kbt-map "p y") #'ignore))
  (should-not (eq (kbt--lookup kbt-map "p y") #'ignore)))

(kbt--test labels
  (kbt--eval (map! :map kbt-map (:prefix ("x" . "ex-desc") "y" #'ignore)))
  (should (eq (kbt--lookup kbt-map "x y") #'ignore))
  (should (kbt--label-p kbt-map "x" "ex-desc"))
  (kbt--eval (map! :map kbt-map :desc "Why" "w" #'ignore))
  (should (kbt--label-p kbt-map "w" "Why"))
  (should (eq (keymap-lookup kbt-map "w") #'ignore)))

(kbt--test labels-state
  (kbt--eval (map! :map kbt-map (:prefix ("x" . "ex-desc") :n "y" #'ignore)))
  (should (eq (kbt--state-lookup 'normal kbt-map "x y") #'ignore))
  (should (kbt--label-p (evil-get-auxiliary-keymap kbt-map 'normal) "x" "ex-desc")))

;;; leader / localleader

(kbt--test leader
  (let ((doom-leader-map (make-sparse-keymap)))
    (kbt--eval (map! :leader "a" #'ignore
                     (:prefix ("b" . "bee") "c" #'forward-char)
                     :desc "Dee" "d" #'backward-char))
    (should (eq (kbt--lookup doom-leader-map "a") #'ignore))
    (should (eq (kbt--lookup doom-leader-map "b c") #'forward-char))
    (should (eq (kbt--lookup doom-leader-map "d") #'backward-char))
    (should (kbt--label-p doom-leader-map "b" "bee"))
    (should (kbt--label-p doom-leader-map "d" "Dee"))))

(kbt--test prefix-map
  (let ((doom-leader-map (make-sparse-keymap)))
    (kbt--eval (map! :leader (:prefix-map ("z" . "zed") "a" #'ignore)))
    (should (boundp 'doom-leader-zed-map))
    (should (keymapp doom-leader-zed-map))
    (should (eq (kbt--lookup doom-leader-map "z a") #'ignore))
    (should (kbt--label-p doom-leader-map "z" "zed"))))

(kbt--test localleader
  (kbt--eval (map! :map kbt-map :localleader "q" #'ignore))
  (let ((key (concat doom-localleader-key " q"))
        (alt (concat doom-localleader-alt-key " q")))
    (dolist (s '(normal visual motion))
      (should (eq (kbt--state-lookup s kbt-map key) #'ignore)))
    (dolist (s '(insert emacs))
      (should (eq (kbt--state-lookup s kbt-map alt) #'ignore))))
  (kbt--eval (map! :map kbt-map :localleader (:prefix "p" "q" #'forward-char)))
  (should (eq (kbt--state-lookup 'normal kbt-map
                                 (concat doom-localleader-key " p q"))
              #'forward-char))
  (should (eq (kbt--state-lookup 'insert kbt-map
                                 (concat doom-localleader-alt-key " p q"))
              #'forward-char)))

;;; conditionals

(kbt--test when-unless
  (kbt--eval (map! :map kbt-map
                   (:when nil "a" #'ignore)
                   (:when t "b" #'ignore)
                   (:unless nil "c" #'ignore)
                   (:unless t "d" #'ignore)))
  (should-not (kbt--lookup kbt-map "a"))
  (should (eq (kbt--lookup kbt-map "b") #'ignore))
  (should (eq (kbt--lookup kbt-map "c") #'ignore))
  (should-not (kbt--lookup kbt-map "d"))
  (kbt--eval (map! :map kbt-map :when nil "e" #'ignore))
  (should-not (kbt--lookup kbt-map "e")))

(kbt--test after
  (setq features (delq 'kbt-fake-feature features))
  (unwind-protect
      (progn
        (kbt--eval (map! :after kbt-fake-feature :map kbt-map "a" #'ignore))
        (should-not (kbt--lookup kbt-map "a"))
        (provide 'kbt-fake-feature)
        (should (eq (kbt--lookup kbt-map "a") #'ignore)))
    (setq features (delq 'kbt-fake-feature features))))

;;; unbinding, remap, textobj

(kbt--test nil-unbinds
  (kbt--eval (map! :map kbt-map "a" #'ignore :n "b" #'ignore))
  (should (kbt--lookup kbt-map "a"))
  (kbt--eval (map! :map kbt-map "a" nil :n "b" nil))
  (should-not (kbt--lookup kbt-map "a"))
  (should-not (kbt--state-lookup 'normal kbt-map "b")))

(kbt--test remap
  (kbt--eval (map! :map kbt-map [remap forward-char] #'backward-char))
  (should (eq (lookup-key kbt-map [remap forward-char]) #'backward-char))
  (kbt--eval (map! :map kbt-map :n [remap next-line] #'previous-line))
  (should (eq (kbt--state-lookup 'normal kbt-map [remap next-line]) #'previous-line)))

(kbt--test textobj
  (unwind-protect
      (progn
        (kbt--eval (map! :textobj "<f35>" #'kbt-inner #'kbt-outer))
        (should (eq (kbt--lookup evil-inner-text-objects-map "<f35>") #'kbt-inner))
        (should (eq (kbt--lookup evil-outer-text-objects-map "<f35>") #'kbt-outer)))
    (define-key evil-inner-text-objects-map (kbd "<f35>") nil)
    (define-key evil-outer-text-objects-map (kbd "<f35>") nil)))

;;; deferred keymaps and auto-unbind

(kbt--test deferred-keymap
  (makunbound 'kbt-later-map)
  (should-not (condition-case err
                  (progn (kbt--eval (map! :map kbt-later-map "a" #'ignore :n "b" #'ignore))
                         nil)
                (error err)))
  (set 'kbt-later-map (make-sparse-keymap))
  (run-hook-with-args 'after-load-functions "kbt")
  (should (eq (kbt--lookup kbt-later-map "a") #'ignore))
  (should (eq (kbt--state-lookup 'normal kbt-later-map "b") #'ignore)))

(kbt--test auto-unbind
  (run-hooks 'doom-after-modules-init-hook)
  (kbt--eval (map! :map kbt-map "a" #'ignore))
  (should-not (condition-case err
                  (progn (kbt--eval (map! :map kbt-map "a b" #'forward-char)) nil)
                (error err)))
  (should (eq (kbt--lookup kbt-map "a b") #'forward-char))
  (kbt--eval (map! :map kbt-map :n "c" #'ignore))
  (should-not (condition-case err
                  (progn (kbt--eval (map! :map kbt-map :n "c d" #'forward-char)) nil)
                (error err)))
  (should (eq (kbt--state-lookup 'normal kbt-map "c d") #'forward-char)))

;;; define-key! / undefine-key!

(kbt--test define-key-positional-map
  (kbt--eval (define-key! kbt-map "a" #'ignore "b" #'forward-char))
  (should (eq (kbt--lookup kbt-map "a") #'ignore))
  (should (eq (kbt--lookup kbt-map "b") #'forward-char)))

(kbt--test define-key-keymaps
  (kbt--eval (define-key! :keymaps 'kbt-map "a" #'ignore))
  (should (eq (kbt--lookup kbt-map "a") #'ignore))
  (kbt--eval (define-key! :keymaps '(kbt-map kbt-map2) "b" #'ignore))
  (should (eq (kbt--lookup kbt-map "b") #'ignore))
  (should (eq (kbt--lookup kbt-map2 "b") #'ignore))
  (kbt--eval (define-key! :keymaps kbt-maps-var "c" #'ignore))
  (should (eq (kbt--lookup kbt-map "c") #'ignore))
  (should (eq (kbt--lookup kbt-map2 "c") #'ignore))
  (kbt--eval (define-key! :keymaps (append kbt-maps-var '(kbt-map3)) "d" #'ignore))
  (dolist (m (list kbt-map kbt-map2 kbt-map3))
    (should (eq (kbt--lookup m "d") #'ignore))))

(kbt--test define-key-state-and-maps
  (kbt--eval (define-key! 'normal (kbt-map kbt-map2) [tab] #'ignore))
  (should (eq (kbt--state-lookup 'normal kbt-map [tab]) #'ignore))
  (should (eq (kbt--state-lookup 'normal kbt-map2 [tab]) #'ignore))
  (kbt--eval (define-key! :states 'insert :keymaps kbt-maps-var "C-j" #'next-line))
  (should (eq (kbt--state-lookup 'insert kbt-map "C-j") #'next-line))
  (should (eq (kbt--state-lookup 'insert kbt-map2 "C-j") #'next-line)))

(kbt--test define-key-global
  (unwind-protect
      (progn
        (kbt--eval (define-key! [remap kbt-cmd] #'ignore))
        (should (eq (lookup-key global-map [remap kbt-cmd]) #'ignore)))
    (define-key global-map [remap kbt-cmd] nil)))

(kbt--test define-key-nil-unbinds
  (kbt--eval (define-key! kbt-map "C-h" #'ignore))
  (should (kbt--lookup kbt-map "C-h"))
  (kbt--eval (define-key! kbt-map "C-h" nil))
  (should-not (kbt--lookup kbt-map "C-h")))

(kbt--test undefine-key
  (kbt--eval (define-key! kbt-map "a" #'ignore "b" #'ignore))
  (kbt--eval (undefine-key! kbt-map "a" "b"))
  (should-not (kbt--lookup kbt-map "a"))
  (should-not (kbt--lookup kbt-map "b")))

;;; override map

(defvar kbt-minor-mode-map (let ((m (make-sparse-keymap)))
                             (define-key m (kbd "<f35>") #'kbt-local)
                             m))
(define-minor-mode kbt-minor-mode "Test minor mode." :keymap kbt-minor-mode-map)

(kbt--test override-wins
  (unwind-protect
      (with-temp-buffer
        (kbt--eval (define-key! 'override "<f35>" #'kbt-over))
        (let ((m (make-sparse-keymap)))
          (define-key m (kbd "<f35>") #'kbt-local)
          (use-local-map m))
        (kbt-minor-mode 1)
        (should (eq (key-binding (kbd "<f35>")) #'kbt-over))
        (kbt-minor-mode -1))
    (kbt--eval (define-key! 'override "<f35>" nil))))

;;; leader resolution in real evil buffers

(defvar kbt-mode-map (make-sparse-keymap))
(define-minor-mode kbt-mode "Test minor mode." :keymap kbt-mode-map)

(defmacro kbt--with-evil-buffer (&rest body)
  `(with-temp-buffer
     (insert "hello world")
     (goto-char (point-min))
     (evil-local-mode 1)
     (unwind-protect (progn ,@body)
       (kbt-mode -1)
       (evil-local-mode -1))))

(defmacro kbt--with-leader (&rest body)
  `(unwind-protect
       (progn
         (kbt--eval (map! :leader "k t" #'kbt-leader-cmd))
         (doom-init-leader-keys-h)
         ,@body)
     (define-key doom-leader-map (kbd "k t") nil)))

(defun kbt--bound-p (key cmd)
  (eq (key-binding (kbd key)) cmd))

(kbt--test leader-states
  (kbt--with-leader
   (kbt--with-evil-buffer
    (evil-normal-state)
    (should (kbt--bound-p "SPC k t" #'kbt-leader-cmd))
    (evil-motion-state)
    (should (kbt--bound-p "SPC k t" #'kbt-leader-cmd))
    (evil-normal-state)
    (evil-visual-char)
    (should (kbt--bound-p "SPC k t" #'kbt-leader-cmd))
    (evil-normal-state)
    (evil-insert-state)
    (should (kbt--bound-p "SPC" #'self-insert-command))
    (should (kbt--bound-p "M-SPC k t" #'kbt-leader-cmd))
    (evil-emacs-state)
    (should (kbt--bound-p "M-SPC k t" #'kbt-leader-cmd)))))

(kbt--test leader-precedence
  (kbt--with-leader
   (kbt--with-evil-buffer
    (evil-define-key* 'normal kbt-mode-map (kbd "SPC") #'ignore)
    (let ((m (make-sparse-keymap)))
      (evil-define-key* 'normal m (kbd "SPC") #'ignore)
      (use-local-map m))
    (kbt-mode 1)
    (evil-normalize-keymaps)
    (evil-normal-state)
    (should (kbt--bound-p "SPC k t" #'kbt-leader-cmd)))))

(kbt--test leader-and-localleader
  (kbt--with-leader
   (kbt--with-evil-buffer
    (kbt--eval (map! :map kbt-mode-map :localleader "q" #'kbt-local-cmd))
    (kbt-mode 1)
    (evil-normalize-keymaps)
    (evil-normal-state)
    (should (kbt--bound-p "SPC m q" #'kbt-local-cmd))
    (evil-insert-state)
    (should (kbt--bound-p "M-SPC m q" #'kbt-local-cmd)))))

;;; the real leader map

(defun kbt--config-leader-form ()
  "The top-level `(:leader ...)' clause of the user's keybindings config, read as data."
  (with-temp-buffer
    (insert-file-contents (kbt--path "config/modules/minh/keybindings/config.el"))
    (let ((form (read (current-buffer))))
      (seq-find (lambda (f) (eq (car-safe f) :leader)) (cdr form)))))

(kbt--test config-leader-spc-label
  (let ((doom-leader-map (make-sparse-keymap))
        (form (kbt--config-leader-form)))
    (should form)
    (eval `(let ((noninteractive nil)) (map! ,form)) t)
    (should (eq (kbt--lookup doom-leader-map "SPC") #'m/find-file))
    (should (equal (kbt--label doom-leader-map "SPC") "Find file in project"))))

;;; no general

(kbt--test no-general
  (should-not (featurep 'general))
  (should-not (fboundp 'general-define-key)))

;;; keybinds-tests.el ends here
