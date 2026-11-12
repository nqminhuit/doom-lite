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

(provide 'popup-tests)
