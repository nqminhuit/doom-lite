;;; modules/doom/compat/+keybinds.el -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; `map!', `define-key!', `undefine-key!' and the leader/localleader keys,
;; implemented on built-in keymaps and evil's `evil-define-key*'.
;;
;;; Code:

(defcustom doom-leader-key "SPC"
  "The leader prefix key for Evil users."
  :type 'key-sequence
  :group 'doom)

(defcustom doom-leader-alt-key "M-SPC"
  "An alternative leader prefix key, used for Insert and Emacs states, and for
non-evil users."
  :type 'key-sequence
  :group 'doom)

(defcustom doom-localleader-key "SPC m"
  "The localleader prefix key, for major-mode specific commands."
  :type 'key-sequence
  :group 'doom)

(defcustom doom-localleader-alt-key "M-SPC m"
  "The localleader prefix key, for major-mode specific commands. Used for Insert
and Emacs states, and for non-evil users."
  :type 'key-sequence
  :group 'doom)

(defcustom doom-leader-key-states '(normal visual motion)
  "which evil modes to activate the leader key for"
  :type '(repeat symbol)
  :group 'doom)

(defcustom doom-leader-alt-key-states '(emacs insert)
  "which evil modes to activate the alternative leader key for"
  :type '(repeat symbol)
  :group 'doom)

(defvar doom-leader-map (make-sparse-keymap)
  "An overriding keymap for <leader> keys.")


;;; ** Override map

(defvar doom-override-mode-map (make-sparse-keymap)
  "Keymap that takes precedence over minor-mode and local maps.")

(define-minor-mode doom-override-mode
  "Enable `doom-override-mode-map', which beats every other keymap."
  :global t)

;; Emulation maps are consulted before minor-mode and local maps.
(defvar doom--override-maps-alist `((doom-override-mode . ,doom-override-mode-map)))
(cl-pushnew 'doom--override-maps-alist emulation-mode-map-alists)

(defconst doom--override-intercept-states
  '(insert emacs normal visual motion operator replace))

;; Intercept maps let SPC beat evil-collection's state bindings in magit, dired, etc.
(with-eval-after-load 'evil
  (dolist (state doom--override-intercept-states)
    (evil-make-intercept-map
     (evil-get-auxiliary-keymap doom-override-mode-map state t t) state)))


;;; ** Backend

(defvar doom--map-auto-unbind nil
  "When non-nil, `doom--define-key' unbinds non-prefix subsequences of a key first.")

;; Prevent "X starts with non-prefix key Y" errors except at startup.
(add-hook 'doom-after-modules-init-hook
          (defun doom--map-enable-auto-unbind-h ()
            (setq doom--map-auto-unbind t)))

(defconst doom--map-non-normal-states '(insert replace emacs))
(defconst doom--map-non-normal-maps
  '(evil-insert-state-map evil-emacs-state-map evil-replace-state-map))

(defun doom--map-concat (&rest keys)
  "Join KEYS (strings or vectors) with spaces, skipping nil and empty ones."
  (mapconcat (lambda (k) (if (vectorp k) (key-description k) k))
             (seq-remove (lambda (k) (or (null k) (equal k ""))) keys)
             " "))

(defun doom--map-kbd (key)
  "Apply `kbd' to KEY when it is a string."
  (if (stringp key) (kbd key) key))

(defun doom--map-unbind (map key)
  "Unbind the non-prefix subsequence of KEY in MAP that would block binding it."
  (when (and (keymapp map) (arrayp key))
    (let ((key (if (stringp key) (string-to-vector key) key)))
      (while (numberp (lookup-key map key))
        (setq key (cl-subseq key 0 -1)))
      (define-key map key nil))))

(defun doom--map-bind (keymap state key def)
  "Bind KEY to DEF in the value of KEYMAP, for evil STATE when non-nil."
  (let ((global (eq keymap 'global)))
    (when (eq keymap 'doom-override-mode-map)
      (doom-override-mode +1))
    (if (null state)
        (let ((map (cond (global (current-global-map))
                         ((symbolp keymap) (symbol-value keymap))
                         (t keymap))))
          (when doom--map-auto-unbind (doom--map-unbind map key))
          (define-key map key def))
      (eval-after-load 'evil
        (lambda ()
          (let ((map (cond (global 'global)
                           ((symbolp keymap) (symbol-value keymap))
                           (t keymap))))
            (when doom--map-auto-unbind
              (doom--map-unbind
               (if global
                   (evil-state-property state :keymap t)
                 (evil-get-auxiliary-keymap map state t t))
               key))
            (evil-define-key* state map key def)))))))

(defvar doom--map-pending nil
  "Entries (KEYMAP-SYMBOL STATE KEY DEF) waiting for KEYMAP-SYMBOL to be bound.")

(defun doom--map-flush-pending (&rest _)
  (let (ready)
    (dolist (entry doom--map-pending)
      (when (boundp (car entry))
        (push entry ready)))
    (setq doom--map-pending (seq-remove (lambda (e) (memq e ready)) doom--map-pending))
    (dolist (entry (nreverse ready))
      (apply #'doom--map-bind entry))
    (unless doom--map-pending
      (remove-hook 'after-load-functions #'doom--map-flush-pending))))

(defun doom--define-key (&rest args)
  "Bind KEY DEF pairs in ARGS.

Keywords (the first occurrence wins): :states, :keymaps (default `global'),
:prefix, :infix and :non-normal-prefix. Keymaps that are not bound yet are
bound as soon as they are."
  (let (opts pairs)
    (while args
      (let ((k (pop args)) (v (pop args)))
        (if (keywordp k)
            (unless (plist-member opts k) (setq opts (plist-put opts k v)))
          (push (cons k v) pairs))))
    (setq pairs (nreverse pairs))
    (let ((states (ensure-list (plist-get opts :states)))
          (keymaps (or (ensure-list (plist-get opts :keymaps)) '(global)))
          (prefix (plist-get opts :prefix))
          (infix (plist-get opts :infix))
          (alt (plist-get opts :non-normal-prefix)))
      (dolist (keymap keymaps)
        (dolist (state (or states '(nil)))
          (let* ((pfx (if (and alt
                               (if state
                                   (memq state doom--map-non-normal-states)
                                 (memq keymap doom--map-non-normal-maps)))
                          alt
                        prefix))
                 (map (if (eq keymap 'override) 'doom-override-mode-map keymap)))
            (pcase-dolist (`(,key . ,def) pairs)
              (let ((key (doom--map-kbd (doom--map-concat pfx infix key)))
                    (def (doom--map-kbd def)))
                (when (> (length key) 0)
                  (if (or (memq map '(global doom-override-mode-map))
                          (not (symbolp map))
                          (boundp map))
                      (doom--map-bind map state key def)
                    (setq doom--map-pending
                          (nconc doom--map-pending (list (list map state key def))))
                    (add-hook 'after-load-functions #'doom--map-flush-pending)))))))))
    nil))

(defun doom--define-key-positional-count (args)
  "Count the leading positional (state and keymap) arguments in ARGS, at most 2."
  (let ((n 0))
    (while (and (< n 2)
                (let ((a (nth n args)))
                  (and a (or (symbolp a) (listp a)) (not (keywordp a)))))
      (cl-incf n))
    n))

(defmacro define-key! (&rest args)
  "Bind keys.

With no leading positional argument, ARGS are `doom--define-key' arguments.
One positional argument is a keymap (or list of keymaps) and two are an evil
state and keymap(s); both are quoted unless already quoted."
  (declare (indent defun))
  (let* ((n (doom--define-key-positional-count args))
         (pos (cl-subseq args 0 n))
         (rest (nthcdr n args))
         (quoted (mapcar (lambda (x) (if (eq (car-safe x) 'quote) x (list 'quote x)))
                         pos)))
    `(doom--define-key
      ,@(pcase n
          (0 nil)
          (1 `(:keymaps ,@quoted))
          (2 `(:states ,(car quoted) :keymaps ,(cadr quoted))))
      ,@rest)))

(defmacro undefine-key! (&rest args)
  "Unbind keys: like `define-key!', but each key is bound to nil.

`:with FN' binds each key to FN instead."
  (declare (indent defun))
  (let* ((n (doom--define-key-positional-count args))
         (out (cl-subseq args 0 n))
         (rest (nthcdr n args))
         (with (if-let* ((cell (plist-member rest :with))) (cadr cell) nil)))
    (when (eq with t) (setq with nil))
    (while rest
      (let ((a (pop rest)))
        (cond ((eq a :with) (pop rest))
              ((keywordp a) (setq out (append out (list a (pop rest)))))
              (t (setq out (append out (list a with)))))))
    `(define-key! ,@out)))


;; HACK: `map!' uses this instead of a full definer because it is much faster
;;   for the many leader bindings at startup.
(defmacro doom--define-leader-key (&rest keys)
  (let (prefix forms)
    (while keys
      (let ((key (pop keys))
            (def (pop keys)))
        (if (keywordp key)
            (when (memq key '(:prefix :infix))
              (setq prefix def))
          (when prefix
            (setq key `(doom--map-concat ,prefix ,key)))
          (unless (eq def :ignore)
            (push `(define-key doom-leader-map (doom--map-kbd ,key) ,def)
                  forms)))))
    (macroexp-progn (nreverse forms))))

(defmacro define-localleader-key! (&rest args)
  "Define <localleader> key.

Does not support :major-modes, :states, :prefix or :non-normal-prefix. Use
`map!' for a more convenient interface.

See `doom-localleader-key' and `doom-localleader-alt-key' to change the
localleader prefix."
  `(doom--define-key
    :states '(normal visual motion emacs insert)
    :prefix doom-localleader-key
    :non-normal-prefix doom-localleader-alt-key
    ,@args))

(unless (doom-context-p 'reload)
  ;; PERF: A prefix command is much cheaper than :prefix/:non-normal-prefix
  ;;   state bindings for every leader key.
  (define-prefix-command 'doom/leader 'doom-leader-map))

;; Bind `doom-leader-key' and `doom-leader-alt-key' as late as possible to give
;; the user a chance to modify them.
(add-hook! 'doom-after-init-hook
  (defun doom-init-leader-keys-h ()
    "Bind `doom-leader-key' and `doom-leader-alt-key'."
    (let ((map doom-override-mode-map)
          (label "<leader>"))
      (if (featurep 'evil)
          (progn
            (evil-define-key* doom-leader-key-states map (kbd doom-leader-key) `(,label . doom/leader))
            (evil-define-key* doom-leader-alt-key-states map (kbd doom-leader-alt-key) `(,label . doom/leader)))
        (cond ((equal doom-leader-alt-key "C-c")
               (set-keymap-parent doom-leader-map mode-specific-map))
              ((equal doom-leader-alt-key "C-x")
               (set-keymap-parent doom-leader-map ctl-x-map)))
        (define-key map (kbd doom-leader-alt-key) `(,label . doom/leader))))
    (doom-override-mode +1)))


;;; ** `map!' macro

(defvar doom-evil-state-alist
  '((?n . normal)
    (?v . visual)
    (?i . insert)
    (?e . emacs)
    (?o . operator)
    (?m . motion)
    (?r . replace)
    (?g . global))
  "A list of cons cells that map a letter to a evil state symbol.")

(defun doom--map-keyword-to-states (keyword)
  "Convert a KEYWORD into a list of evil state symbols.

For example, :nvi will map to (list \\='normal \\='visual \\='insert). See
`doom-evil-state-alist' to customize this."
  (cl-loop for l across (doom-keyword-name keyword)
           if (assq l doom-evil-state-alist) collect (cdr it)
           else do (error "not a valid state: %s" l)))


;; specials
(defvar doom--map-forms nil)
(defvar doom--map-fn nil)
(defvar doom--map-batch-forms nil)
(defvar doom--map-state '(:dummy t))
(defvar doom--map-parent-state nil)
(defvar doom--map-evil-p nil)
(defvar doom--map-last-prefix nil)
(with-eval-after-load 'evil (setq doom--map-evil-p t))

(defun doom--map-process (rest)
  (let ((doom--map-fn doom--map-fn)
        doom--map-state
        doom--map-forms
        desc)
    (while rest
      (let ((key (pop rest)))
        (cond ((listp key)
               (doom--map-nested nil key))

              ((keywordp key)
               (pcase key
                 (:leader
                  (doom--map-commit)
                  (setq doom--map-fn 'doom--define-leader-key))
                 (:localleader
                  (doom--map-commit)
                  (setq doom--map-fn 'define-localleader-key!))
                 (:after
                  (doom--map-nested (list 'after! (pop rest)) rest)
                  (setq rest nil))
                 (:desc
                  (setq desc (pop rest)))
                 (:map
                  (doom--map-set :keymaps `(backquote ,(ensure-list (pop rest)))))
                 ((or :when :unless)
                  (doom--map-nested (list (intern (doom-keyword-name key)) (pop rest)) rest)
                  (setq rest nil))
                 (:prefix-map
                  (cl-destructuring-bind (prefix . desc)
                      (let ((arg (pop rest)))
                        (if (consp arg) arg (list arg)))
                    (let ((keymap (intern (format "doom-leader-%s-map" desc))))
                      (setq rest
                            (append (list :desc desc prefix keymap
                                          :prefix prefix)
                                    rest))
                      (push `(defvar ,keymap (make-sparse-keymap))
                            doom--map-forms))))
                 (:prefix
                  (cl-destructuring-bind (prefix . desc)
                      (let ((arg (pop rest)))
                        (if (consp arg) arg (list arg)))
                    (doom--map-set (if doom--map-fn :infix :prefix)
                                   prefix)
                    (when (stringp desc)
                      (setq doom--map-last-prefix (cons nil desc)))))
                 (:textobj
                  (let* ((key (pop rest))
                         (inner (pop rest))
                         (outer (pop rest)))
                    (push `(map! (:map evil-inner-text-objects-map ,key ,inner)
                                 (:map evil-outer-text-objects-map ,key ,outer))
                          doom--map-forms)))
                 (_
                  (condition-case _
                      (doom--map-def (pop rest) (pop rest)
                                     (doom--map-keyword-to-states key)
                                     desc)
                    (error
                     (error "Not a valid `map!' property: %s" key)))
                  (setq desc nil))))

              ((doom--map-def key (pop rest) nil desc)
               (setq desc nil)))))

    (doom--map-commit)
    (macroexp-progn (nreverse (delq nil doom--map-forms)))))

(defun doom--map-append-keys (prop)
  (let ((a (plist-get doom--map-parent-state prop))
        (b (plist-get doom--map-state prop)))
    (if (and a b)
        `(doom--map-concat ,a ,b)
      (or a b))))

(defun doom--map-nested (wrapper rest)
  (doom--map-commit)
  (let ((doom--map-parent-state (doom--map-state)))
    (push (if wrapper
              (append wrapper (list (doom--map-process rest)))
            (doom--map-process rest))
          doom--map-forms)))

(defun doom--map-set (prop &optional value)
  (unless (equal (plist-get doom--map-state prop) value)
    (doom--map-commit))
  (setq doom--map-state (plist-put doom--map-state prop value)))

(defun doom--map-def (key def &optional states desc)
  (when (or (memq 'global states)
            (null states))
    (setq states (cons 'nil (delq 'global states))))
  (when desc
    (cond ((and (equal key "")
                (null def))
           (setq doom--map-last-prefix nil)
           (setq def `(cons ,desc (make-sparse-keymap))))
          ((setq def `(cons ,desc ,def)))))
  (dolist (state states)
    (when (and doom--map-last-prefix
               (not (memq state (car doom--map-last-prefix))))
      (push state (car doom--map-last-prefix))
      (push (list "" `(cons ,(cdr doom--map-last-prefix) (make-sparse-keymap)))
            (alist-get state doom--map-batch-forms)))
    (push (list key def)
          (alist-get state doom--map-batch-forms)))
  t)

(defun doom--map-commit ()
  (when doom--map-batch-forms
    (cl-loop with attrs = (doom--map-state)
             for (state . defs) in doom--map-batch-forms
             if (or doom--map-evil-p (not state))
             collect `(,(or doom--map-fn 'doom--define-key)
                       ,@(if state `(:states ',state)) ,@attrs
                       ,@(mapcan #'identity (nreverse defs)))
             into forms
             finally do (push (macroexp-progn forms) doom--map-forms))
    (setq doom--map-last-prefix nil)
    (setq doom--map-batch-forms nil)))

(defun doom--map-state ()
  (let ((plist
         (append (list :prefix (doom--map-append-keys :prefix)
                       :infix  (doom--map-append-keys :infix)
                       :keymaps
                       (append (plist-get doom--map-parent-state :keymaps)
                               (plist-get doom--map-state :keymaps)))
                 doom--map-state
                 nil))
        newplist)
    (while plist
      (let ((key (pop plist))
            (val (pop plist)))
        (when (and val (not (plist-member newplist key)))
          (push val newplist)
          (push key newplist))))
    newplist))

(defmacro map! (&rest rest)
  "A convenience macro for defining keybinds, built on keymaps and evil.

If evil isn't loaded, evil-specific bindings are ignored.

Properties
  :leader [...]                   an alias for (:map doom-leader-map ...)
  :localleader [...]              bind to localleader; requires a keymap
  :map [KEYMAP(s)] [...]          inner keybinds are applied to KEYMAP(S)
  :prefix [PREFIX] [...]          set keybind prefix for following keys. PREFIX
                                  can be a cons cell: (PREFIX . DESCRIPTION).
                                  WARNING: Providing a DESCRIPTION here will
                                  unset any previous keys on PREFIX!
  :prefix-map [PREFIX] [...]      same as :prefix, but defines a prefix keymap
                                  where the following keys will be bound. DO NOT
                                  USE THIS IN YOUR PRIVATE CONFIG.
  :after [FEATURE] [...]          apply keybinds when [FEATURE] loads
  :textobj KEY INNER-FN OUTER-FN  define a text object keybind pair
  :when [CONDITION] [...]
  :unless [CONDITION] [...]

  Any of the above properties may be nested, so that they only apply to a
  certain group of keybinds.

States
  :n  normal
  :v  visual
  :i  insert
  :e  emacs
  :o  operator
  :m  motion
  :r  replace
  :g  global  (binds the key without evil `current-global-map')

  These can be combined in any order, e.g. :nvi will apply to normal, visual and
  insert mode. The state resets after the following key=>def pair. If states are
  omitted the keybind will be global (no emacs state; this is different from
  evil's Emacs state and will work in the absence of `evil-mode').

  These must be placed right before the key string.

  Do
    (map! :leader :desc \"Description\" :n \"C-c\" \\=#'dosomething)
  Don't
    (map! :n :leader :desc \"Description\" \"C-c\" \\=#'dosomething)
    (map! :leader :n :desc \"Description\" \"C-c\" \\=#'dosomething)"
  (when (or (bound-and-true-p byte-compile-current-file)
            (not noninteractive))
    (doom--map-process rest)))

;;; +keybinds.el ends here
