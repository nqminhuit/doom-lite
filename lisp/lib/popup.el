;;; lisp/lib/popup.el -*- lexical-binding: t; -*-
;;; Commentary:
;; Thin layer that maps `set-popup-rule!' onto `display-buffer-alist'.

;;; Code:

(defconst doom--popup-default-height 0.16
  "Window height of popups on the top/bottom when no size is given.")

(defconst doom--popup-default-width 40
  "Window width of popups on the left/right when no size is given.")

(defun doom--popup-make-rule (predicate plist)
  "Build a `display-buffer-alist' entry for PREDICATE from the popup PLIST."
  (if (plist-get plist :ignore)
      (list predicate nil)
    (let* ((side (or (plist-get plist :side) 'bottom))
           (vertical (memq side '(left right)))
           (size-key (if vertical 'window-width 'window-height))
           (size (plist-get plist :size))
           (height (plist-get plist :height))
           (width (plist-get plist :width))
           (slot (plist-get plist :slot))
           (alist `((side . ,side))))
      (cond (size (push (cons size-key size) alist))
            ((or height width)
             (when height (push (cons 'window-height height) alist))
             (when width (push (cons 'window-width width) alist)))
            (t (push (if vertical
                         (cons 'window-width doom--popup-default-width)
                       (cons 'window-height doom--popup-default-height))
                     alist)))
      (when slot (push (cons 'slot slot) alist))
      (when (eq (plist-get plist :select) t)
        (push (cons 'body-function #'select-window) alist))
      (let ((quit (if (plist-member plist :quit) (plist-get plist :quit) t)))
        (when quit
          (push `(window-parameters (quit . ,quit)) alist)))
      `(,predicate (display-buffer-reuse-window display-buffer-in-side-window)
                   ,@(nreverse alist)))))

;;;###autoload
(defun set-popup-rule! (predicate &rest plist)
  "Display buffers matching PREDICATE in a side window, per PLIST.

Adds (or replaces, for an `equal' PREDICATE) an entry in `display-buffer-alist'.
PLIST keys: :side, :size (or :height/:width), :slot, :select, :quit, :ignore.
:select t selects the window; :quit is t, `current', `other' or nil and is
honored by `doom-popup-close-on-escape-h'. :ignore t shadows later rules.
:vslot, :ttl, :modeline, :autosave, :actions and :parameters are ignored."
  (declare (indent defun))
  (let ((rule (doom--popup-make-rule predicate plist))
        (old (assoc predicate display-buffer-alist)))
    (if old
        (setcdr old (cdr rule))
      (push rule display-buffer-alist))
    display-buffer-alist))

;;;###autoload
(defun set-popup-rules! (&rest rulesets)
  "Call `set-popup-rule!' for every (PREDICATE . PLIST) in each of RULESETS."
  (declare (indent 0))
  (dolist (rules rulesets)
    (dolist (rule rules)
      (apply #'set-popup-rule! rule)))
  display-buffer-alist)

;;;###autoload
(defun doom-popup-close-on-escape-h ()
  "Close side windows according to their `quit' parameter; for `doom-escape-hook'.
Inside a side window, close it if quit is t or `current'. Elsewhere, close
every side window whose quit is t or `other'. Return non-nil if one closed."
  (let ((win (selected-window)))
    (if (window-parameter win 'window-side)
        (when (memq (window-parameter win 'quit) '(t current))
          (delete-window win)
          t)
      (let (closed)
        (dolist (w (window-list))
          (when (and (window-parameter w 'window-side)
                     (memq (window-parameter w 'quit) '(t other)))
            (delete-window w)
            (setq closed t)))
        closed))))

;;;###autoload
(add-to-list 'window-persistent-parameters '(quit . writable))

;;;###autoload
(add-hook 'doom-escape-hook #'doom-popup-close-on-escape-h 'append)

;;; popup.el ends here
