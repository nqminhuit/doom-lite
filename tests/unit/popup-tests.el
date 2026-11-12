;;; popup-tests.el --- set-popup-rule! behavior -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst pt--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defun pt--path (rel) (expand-file-name rel pt--root))

;; Old implementation if modules/ui/popup exists, else the core shim.
(if (file-directory-p (pt--path "modules/ui/popup"))
    (progn
      (load (pt--path "lisp/doom-lib.el") nil t)
      (unless (fboundp 'modulep!) (defmacro modulep! (&rest _) nil))
      (load (pt--path "modules/ui/popup/autoload/settings.el") nil t)
      (load (pt--path "modules/ui/popup/autoload/popup.el") nil t)
      (cl-letf (((symbol-function 'load!) #'ignore))
        (load (pt--path "modules/ui/popup/config.el") nil t))
      (+popup-mode 1))
  (load (pt--path "lisp/doom-lib.el") nil t)
  (load (pt--path "lisp/lib/popup.el") nil t))

(defun pt--reset ()
  (setq display-buffer-alist nil)
  (when (boundp '+popup--display-buffer-alist)
    (setq +popup--display-buffer-alist nil))
  (let ((ignore-window-parameters t))
    (dolist (w (window-list))
      (when (and (window-parameter w 'window-side) (cdr (window-list)))
        (delete-window w)))
    (delete-other-windows (window-main-window))
    (select-window (window-main-window)))
  (dolist (b (buffer-list))
    (when (string-prefix-p "*pt-" (buffer-name b)) (kill-buffer b))))

(defmacro pt--with-fixture (&rest body)
  `(unwind-protect (progn (pt--reset) ,@body)
     (pt--reset)))

(defun pt--show (name)
  "Display buffer NAME with `display-buffer'; return its window."
  (display-buffer (get-buffer-create name)))

(defun pt--side-of (win) (window-parameter win 'window-side))

(ert-deftest popup/side ()
  (dolist (side '(bottom top left right))
    (pt--with-fixture
     (let ((name (format "*pt-%s*" side)))
       (set-popup-rule! (regexp-quote name) :side side)
       (should (eq side (pt--side-of (pt--show name))))))))

(ert-deftest popup/size-bottom ()
  (pt--with-fixture
   (set-popup-rule! "^\\*pt-a" :side 'bottom :size 0.3)
   (let ((h (window-total-height (pt--show "*pt-a*")))
         (want (* 0.3 (frame-height))))
     (should (<= (abs (- h want)) 2)))))

(ert-deftest popup/size-left ()
  (pt--with-fixture
   (set-popup-rule! "^\\*pt-a" :side 'left :size 0.3)
   (let ((w (window-total-width (pt--show "*pt-a*")))
         (want (* 0.3 (frame-width))))
     (should (<= (abs (- w want)) 2)))))

(ert-deftest popup/slot ()
  (pt--with-fixture
   (set-popup-rule! "^\\*pt-a" :side 'bottom :slot 2)
   (should (eql 2 (window-parameter (pt--show "*pt-a*") 'window-slot)))))

(ert-deftest popup/select ()
  (pt--with-fixture
   (set-popup-rule! "^\\*pt-sel" :side 'bottom :select t)
   (set-popup-rule! "^\\*pt-nosel" :side 'top :select nil)
   (let* ((origin (selected-window))
          (w1 (pt--show "*pt-sel*")))
     (should (eq w1 (selected-window)))
     (select-window origin)
     (pt--show "*pt-nosel*")
     (should (eq origin (selected-window))))))

(ert-deftest popup/ignored-keywords ()
  (pt--with-fixture
   (set-popup-rule! "^\\*pt-a" :side 'right :vslot 3 :ttl 0 :modeline nil
                    :autosave t)
   (should (eq 'right (pt--side-of (pt--show "*pt-a*"))))))

(ert-deftest popup/later-rule-wins ()
  (pt--with-fixture
   (set-popup-rule! "^\\*pt-a" :side 'bottom)
   (set-popup-rule! "^\\*pt-a" :side 'left)
   (should (eq 'left (pt--side-of (pt--show "*pt-a*"))))))

(ert-deftest popup/rules-plural ()
  (pt--with-fixture
   (set-popup-rules!
     '(("^\\*pt-b" :side bottom) ("^\\*pt-t" :side top))
     nil
     '(("^\\*pt-l" :side left)))
   (should (eq 'bottom (pt--side-of (pt--show "*pt-b*"))))
   (should (eq 'top (pt--side-of (pt--show "*pt-t*"))))
   (should (eq 'left (pt--side-of (pt--show "*pt-l*"))))))

(defun pt--esc-from (win)
  (with-selected-window win
    (run-hook-with-args-until-success 'doom-escape-hook)))

(defun pt--quit-case (quit-args from-popup)
  "Show a popup with QUIT-ARGS, run ESC from the popup or main window; return the popup if still live."
  (apply #'set-popup-rule! "^\\*pt-q" :side 'bottom quit-args)
  (let* ((main (selected-window))
         (pop (pt--show "*pt-q*")))
    (pt--esc-from (if from-popup pop main))
    (window-live-p pop)))

(ert-deftest popup/quit-t ()
  (pt--with-fixture
   (should-not (pt--quit-case '(:quit t) nil)))
  (pt--with-fixture
   (should-not (pt--quit-case '(:quit t) t))))

(ert-deftest popup/quit-current ()
  (pt--with-fixture
   (should (pt--quit-case '(:quit current) nil)))
  (pt--with-fixture
   (should-not (pt--quit-case '(:quit current) t))))

(ert-deftest popup/quit-nil ()
  (pt--with-fixture
   (should (pt--quit-case '(:quit nil) nil)))
  (pt--with-fixture
   (should (pt--quit-case '(:quit nil) t))))

;;; Shim-only tests: exact `display-buffer-alist' entries.

(defconst pt--fns '(display-buffer-reuse-window display-buffer-in-side-window))

(defun pt--entry (pred &rest plist)
  "The entry `set-popup-rule!' leaves for PRED, from a clean alist."
  (setq display-buffer-alist nil)
  (apply #'set-popup-rule! pred plist)
  (car display-buffer-alist))

(defmacro pt--shim-test (name &rest body)
  (declare (indent 1))
  `(ert-deftest ,name ()
     (skip-unless (fboundp 'doom-popup-close-on-escape-h))
     (pt--with-fixture ,@body)))

(pt--shim-test popup-shim/side
  (should (equal (pt--entry "a" :side 'top :quit nil)
                 `("a" ,pt--fns (side . top) (window-height . 0.16)))))

(pt--shim-test popup-shim/size
  (should (equal (pt--entry "a" :size 0.3 :quit nil)
                 `("a" ,pt--fns (side . bottom) (window-height . 0.3))))
  (should (equal (pt--entry "a" :side 'left :size 30 :quit nil)
                 `("a" ,pt--fns (side . left) (window-width . 30))))
  (should (equal (pt--entry "a" :size 'fit-window-to-buffer :quit nil)
                 `("a" ,pt--fns (side . bottom)
                   (window-height . fit-window-to-buffer))))
  (should (equal (pt--entry "a" :side 'right :height 5 :width 20 :quit nil)
                 `("a" ,pt--fns (side . right)
                   (window-height . 5) (window-width . 20)))))

(pt--shim-test popup-shim/default-size
  (should (equal (pt--entry "a" :side 'left :quit nil)
                 `("a" ,pt--fns (side . left) (window-width . 40)))))

(pt--shim-test popup-shim/slot
  (should (equal (pt--entry "a" :slot 2 :quit nil)
                 `("a" ,pt--fns (side . bottom) (window-height . 0.16)
                   (slot . 2)))))

(pt--shim-test popup-shim/select
  (should (equal (pt--entry "a" :select t :quit nil)
                 `("a" ,pt--fns (side . bottom) (window-height . 0.16)
                   (body-function . select-window))))
  (should (equal (pt--entry "a" :select nil :quit nil)
                 (pt--entry "a" :quit nil)))
  (should (equal (pt--entry "a" :select #'ignore :quit nil)
                 (pt--entry "a" :quit nil))))

(pt--shim-test popup-shim/quit
  (should (equal (pt--entry "a" :quit 'current)
                 `("a" ,pt--fns (side . bottom) (window-height . 0.16)
                   (window-parameters (quit . current)))))
  (should (equal (pt--entry "a")
                 (pt--entry "a" :quit t)))
  (should (equal (cdr (assq 'window-parameters (cdr (pt--entry "a"))))
                 '((quit . t)))))

(pt--shim-test popup-shim/ignored-keywords
  (should (equal (pt--entry "a" :side 'left :vslot 3 :ttl 0 :modeline nil
                            :autosave t :actions '(foo) :parameters '((x . 1)))
                 (pt--entry "a" :side 'left))))

(pt--shim-test popup-shim/replace-same-predicate
  (setq display-buffer-alist nil)
  (set-popup-rule! "a" :side 'left)
  (set-popup-rule! "b" :side 'top)
  (set-popup-rule! "a" :side 'right)
  (should (= 2 (length display-buffer-alist)))
  (should (eq 'right (cdr (assq 'side (cddr (assoc "a" display-buffer-alist)))))))

(pt--shim-test popup-shim/keeps-user-entries
  (let ((user '("user" display-buffer-pop-up-window)))
    (setq display-buffer-alist (list user))
    (set-popup-rule! "a" :side 'left)
    (should (member user display-buffer-alist))
    (should (= 2 (length display-buffer-alist)))))

(pt--shim-test popup-shim/rules-equal-one-by-one
  (setq display-buffer-alist nil)
  (set-popup-rules! '(("a" :side left :slot 1) ("b" :size 0.5)) nil
                    '(("c" :select t)))
  (let ((plural display-buffer-alist))
    (setq display-buffer-alist nil)
    (set-popup-rule! "a" :side 'left :slot 1)
    (set-popup-rule! "b" :size 0.5)
    (set-popup-rule! "c" :select t)
    (should (equal plural display-buffer-alist))))

(pt--shim-test popup-shim/ignore
  (should (equal (pt--entry "a" :ignore t :side 'left) '("a" nil))))

(pt--shim-test popup-shim/escape-hook-registered
  (should (memq #'doom-popup-close-on-escape-h doom-escape-hook)))

;; `quit' must survive window-state round-trips such as C-`.
(pt--shim-test popup-shim/quit-survives-toggle
  (set-popup-rule! "^\\*pt-q" :side 'bottom :quit t)
  (let ((buf (get-buffer-create "*pt-q*")))
    (display-buffer buf)
    (window-toggle-side-windows)
    (window-toggle-side-windows)
    (let ((win (get-buffer-window buf)))
      (should win)
      (should (eq t (window-parameter win 'quit))))
    (select-window (window-main-window))
    (run-hook-with-args-until-success 'doom-escape-hook)
    (should-not (get-buffer-window buf))))

(provide 'popup-tests)
