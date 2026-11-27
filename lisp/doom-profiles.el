;;; lisp/doom-profiles.el -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

;;
;;; * Variables

(defvar doom-profile-init-dir-name "init.d"
  "The subdirectory of `doom-profile-dir'.")

;;; Profile storage variables
(define-obsolete-variable-alias 'doom-profile-generators 'doom-profile-generate-functions "2.3.0")
(defvar doom-profile-generate-functions
  '(doom-profile--generate-init
    doom-profile--generate-loaddefs-doom
    doom-profile--generate-user-init-loader
    doom-profile--generate-loaddefs-packages
    doom-profile--generate-loaddefs-modules
    doom-profile--generate-module-loader)
  "An alist mapping file names to generator functions.

Functions are responsible for generating the profile init files that will be
concatenated into a single, monolithic one. Init files should be prefixed with a
two digit number so they execute in the desired order. Init files with the
following suffixes have special behaviors:

  *.init.el -- will be concatenated verbatim into the profile init file.
  *.load.el -- will be `doom-load'ed by the profile init file.

These functions are executed in the context of the
`doom-profile-dir'/`doom-profile-init-dir-name' directory.")


;;
;;; * Library

;;;###autoload
(eval-and-compile
  (cl-defstruct (doom-profile (:copier nil))
    "TODO"
    name
    ref
    root
    ;; hash       ; profile is initialized & synced
    active-p
    ;; recipe-overrides
    ;; source-overrides
    ;; module-overrides
    ;; package-overrides
    ;; (sources (make-hash-table :test 'eq) :read-only t)
    ;; (modules (make-hash-table :test 'equal) :read-only t)
    ;; (packages (make-hash-table :test 'eq) :read-only t)
    ;; (-module-paths (make-hash-table :test 'equal) :read-only t)
    ;; (-source-paths (make-hash-table :test 'equal) :read-only t)
    ;; (metadata '((t)))
    ;; bindings
    ;; (build-system system-configuration)
    ;; (build-version emacs-version)
    ;; build-time
    )

  (pcase-defmacro doom-profile (&rest fields)
    `(doom-struct doom-profile ,@fields))

  (defun doom-profile-key (profile &optional default?)
    "Normalize PROFILE into a (NAME . REF) doom-profile key.

PROFILE can be a `doom-profile' struct, a profile id string (in the NAME@REF
format), a (NAME . REF) cons cell, or `t' to return the fallback key:
(\"_default\" .  0).

NAME is the string name of the profile and REF can either be a string (arbitrary
label) or an integer (generation number).

Throws `wrong-type-argument' if PROFILE is nil and DEFAULT? is omitted.

If DEFAULT? is non-nil, an unspecified NAME and/or REF field will be filled in
with the corresponding one from the fallback key."
    (declare (pure t) (side-effect-free t))
    (let ((default-name (if default? (car doom--profile-default)))
          (default-ref  (if default? (cdr doom--profile-default))))
      (cond ((or (eq profile t)
                 (and (null profile) default?))
             (cons default-name default-ref))
            ((stringp profile)
             (save-match-data
               (let (case-fold-search)
                 (if (string-match "^\\([^@]+\\)?\\(?:@\\(.+\\)\\)?$" profile)
                     (cons (match-string 1 profile)
                           (or (match-string 2 profile) default-ref))
                   (cons profile default-name)))))
            ((doom-profile-p profile)
             (cons (or (doom-profile-name profile) default-name)
                   (or (doom-profile-ref profile)  default-ref)))
            ((and (consp profile) (nlistp (cdr profile)))
             (cons (or (car profile) default-name)
                   (or (cdr profile) default-ref)))
            ((signal 'wrong-type-argument
                     (list "Expected PROFILE to be a string, cons cell, or `doom-profile'"
                           (type-of profile) profile)))))))

;;;###autoload
(defun doom-profile->id (profile)
  "Return a NAME@VERSION id string from PROFILE.

See `doom-profile-key' for possible values of PROFILE."
  (cl-destructuring-bind (name . ref) (doom-profile-key profile)
    (format "%s@%s" name ref)))


;;; ** Profile Generators

(defun doom-profile-generate (&optional profile reload?)
  "Generate PROFILE init files.

Regenerates the last profile if RELOAD? is non-nil."
  (doom-initialize-packages)
  (let* ((p (or profile doom-profile))
         (default-directory (doom-profile-init-dir p))
         (init-dir  (doom-profile-init-dir p doom-profile-init-dir-name))
         (init-dir* (doom-profile-dir p doom-profile-init-dir-name))
         (init-file (doom-profile-init-file p)))
    (print! (start "Generating profile init file"))
    (condition-case-unless-debug e
        (with-file-modes #o750
          (print-group!
            (if reload?
                (if (not (file-directory-p init-dir))
                    (user-error "No pre-existing profile to reload")
                  (cl-loop for file in (doom-glob init-dir* "*.el")
                           do (copy-file file (file-name-as-directory init-dir) t)))
              (delete-directory init-dir t)
              (make-directory init-dir t)
              ;; Where persisted profile files are preserved.
              (when (file-directory-p init-dir*)
                (copy-directory init-dir* init-dir nil t t))
              (let ((default-directory (doom-path init-dir)))
                ;; TODO: (run-hook-with-args 'doom-profile-generate-functions p)
                (dolist (fn doom-profile-generate-functions)
                  (if (symbolp fn)
                      (funcall fn p)
                    ;; DEPRECATED: Backwards compatibility. Remove in v3.
                    (pcase-let* ((`(,file ,fn _) fn)
                                 (file (doom-path init-dir file)))
                      (doom-log "Building %s..." file)
                      (doom-file-write file (funcall fn) :printfn #'prin1))))))
            (doom-file-write
             init-file
             `(";; -*- coding: utf-8; lexical-binding: t; no-byte-compile: t -*-"
               ";; This file was autogenerated; do not edit it by hand!"
               ,@(cl-loop for file in (doom-glob init-dir "*.el")
                          do (print! (item "Reading %s...") (filename file))
                          if (and (or (string-suffix-p ".init.el" file)
                                      ;; DEPRECATED: Backwards compatibility.
                                      ;;   Remove in v3.
                                      (string-suffix-p ".auto.el" file))
                                  (doom-file-cookie-p file "if" t))
                          append (doom-file-read file :by 'read*)
                          else if (string-suffix-p ".load.el" file)
                          collect `(if ,(doom-file-cookie file "if" t)
                                       (doom-load ,(abbreviate-file-name file)
                                                  t)))
               ;; DEPRECATED: Backwards compatibility. Remove in v3.
               ,@(cl-loop for fn in doom-profile-generate-functions
                          if (not (functionp fn))
                          if (functionp (nth 2 fn))
                          collect `(add-hook 'doom-startup-functions ',(nth 2 fn) 'append))))
            (print! (success "Built %s") (filename init-file))))
      (error (ignore-errors (delete-file init-file))
             (signal 'doom-autoload-error (list init-file e))))))

(defun doom-profile--generate-init (profile)
  (doom-file-write
   "05-doom.init.el"
   `((setq doom-profile ,profile)
     (put 'doom 'version ,(doom-version))
     (defun doom--startup-vars (_profile)
       (when (doom-context-p 'reload)
         (set-default-toplevel-value 'load-path (get 'load-path 'initial-value)))
       ,@(cl-loop for var in '(auto-mode-alist
                               interpreter-mode-alist
                               magic-mode-alist
                               magic-fallback-mode-alist)
                  collect `(set-default-toplevel-value ',var ',(symbol-value var)))
       ;; Ensure site lisp entries are placed at the end of `load-path' in
       ;; interactive sessions, or malformed/strange EMACSLOADPATH values could
       ;; mess with load order expectations.
       ,@(cl-loop for path in (reverse (get 'load-path 'initial-value))
                  collect `(add-to-list 'load-path ,path))
       ,@(cl-loop with init-load-path = (get 'load-path 'initial-value)
                  with site-run-dir =
                  (ignore-errors
                    (directory-file-name (file-name-directory
                                          (locate-library site-run-file))))
                  for path in load-path
                  unless (member path init-load-path)
                  unless (file-equal-p path doom-core-dir)
                  unless (file-in-directory-p path data-directory)
                  unless (and site-run-dir (file-in-directory-p path site-run-dir))
                  collect `(add-to-list 'load-path ,path))
       ,@(cl-loop with emacs-dir = (doom-emacs-dir)
                  with ref = (doom-call-process "git" "-C" emacs-dir "rev-parse" "HEAD")
                  with branch = (doom-call-process "git" "-C" emacs-dir "branch" "--show-current")
                  for (var . val)
                  in `((revision . ,(if (zerop (car ref)) (cdr ref)))
                       (branch   . ,(if (zerop (car branch)) (cdr branch))))
                  collect `(put 'doom ',var ',val)))
     (add-hook 'doom-startup-functions #'doom--startup-vars 5))))

(defun doom-profile--generate-loaddefs-doom (_profile)
  (doom-file-write
   "10-doom-loaddefs.init.el"
   `((static-unless noninteractive
       ,@(doom-loaddefs-scan (doom-glob doom-core-dir "doom-*.el")))))
  (doom-file-write
   "10-doom-cli-loaddefs.load.el"
   `(";; -*- lexical-binding: t; no-byte-compile t; -*-"
     ";;;###if noninteractive"
     ,@(doom-loaddefs-scan
        (doom-glob doom-core-dir "cli/*.el")
        (cl-loop for dir in (doom-module-load-path nil t)
                 append (doom-glob dir doom-module-cli-file))))))

(defun doom-profile--generate-user-init-loader (_profile)
  (doom-file-write
   "20-user.init.el"
   `((static-unless noninteractive
       (with-doom-context '(module init)
         (doom-load ,(doom-user-dir doom-module-init-file) t))))))

(defun doom-profile--generate-loaddefs-modules (_profile)
  (doom-file-write
   "60-doom-module-loaddefs.init.el"
   `((defun doom--startup-loaddefs-modules (_profile)
       ,@(doom-loaddefs-scan
          (doom-glob doom-core-dir "lib/*.el")
          (cl-loop for dir in (doom-module-load-path :all t)
                   if (doom-glob dir "autoload.el") collect (car it)
                   if (doom-glob dir "autoload/*.el") append it)))
     (add-hook 'doom-startup-functions #'doom--startup-loaddefs-modules 60))))

(defun doom-profile--generate-loaddefs-packages (_profile)
  (doom-packages--check-built)
  (doom-file-write
   "70-doom-package-loaddefs.init.el"
   `((defun doom--startup-loaddefs-packages (_profile)
       ,@(doom-loaddefs-scan-literal
          ;; Dependencies first, so any load-order constraints in package
          ;; autoloads are always met.
          (mapcar #'doom-packages--autoloads-file
                  (doom-packages--toposort (doom-packages--installed)
                                           #'doom-package-dependencies)))
       ,@(when-let* ((info-dirs
                      (cl-loop for dir in load-path
                               if (file-exists-p (doom-path dir "dir"))
                               collect dir)))
           `((with-eval-after-load 'info
               (info-initialize)
               (dolist (path ',(delete-dups info-dirs))
                 (add-to-list 'Info-directory-list path))))))
     (add-hook 'doom-startup-functions #'doom--startup-loaddefs-packages 70))))

(defun doom-profile--generate-module-loader (_profile)
  (doom-file-write
   "80-doom-modules.init.el"
   (let* ((init-modules-list (doom-module-list nil t))
          (config-modules-list (doom-module-list))
          (pre-init-modules
           (seq-filter (fn! (<= (car (doom-module-get % :depth)) -100))
                       (remove '(:user . nil) init-modules-list)))
          (init-modules
           (seq-filter (fn! (<= 0 (car (doom-module-get % :depth)) 100))
                       init-modules-list))
          (config-modules
           (seq-filter (fn! (<= 0 (cdr (doom-module-get % :depth)) 100))
                       config-modules-list))
          (post-config-modules
           (seq-filter (fn! (>= (cdr (doom-module-get % :depth)) 100))
                       config-modules-list))
          (init-file   doom-module-init-file)
          (config-file doom-module-config-file))
     (letf! ((defun module-loader (key file)
               (when (and (file-exists-p file)
                          (doom-file-cookie-p file "if" t))
                 `(with-doom-module ',key
                    (doom-load ,(abbreviate-file-name
                                 (file-name-sans-extension file))))))
             (defun module-list-loader (modules file)
               (cl-loop for key in modules
                        if (or (doom-module-expand-path key file)
                               (doom-module-locate-path key file))
                        collect (module-loader key it))))
       ;; FIX: Same as above (see `doom-profile--generate-init-vars').
       `((set 'doom-modules ',doom-modules)
         (set 'doom-disabled-packages ',doom-disabled-packages)
         (static-unless noninteractive
           ;; Cache module state and flags in symbol plists for quick lookup by
           ;; `modulep!' later.
           ,@(cl-loop
              for (category . modules) in (seq-group-by #'car config-modules-list)
              collect
              `(setplist ',category
                (quote ,(cl-loop for (_ . module) in modules
                                 nconc `(,module ,(doom-module->context (cons category module))))))))
         (defun doom--startup-modules (_profile)
           (with-doom-context 'module
             (let ((old-custom-file custom-file))
               (with-doom-context 'init
                 ,@(module-list-loader pre-init-modules init-file)
                 (doom-run-hooks 'doom-before-modules-init-hook)
                 ,@(module-list-loader init-modules init-file)
                 (doom-run-hooks 'doom-after-modules-init-hook))
               (with-doom-context 'config
                 (doom-run-hooks 'doom-before-modules-config-hook)
                 ,@(module-list-loader config-modules config-file)
                 (doom-run-hooks 'doom-after-modules-config-hook)
                 ,@(module-list-loader post-config-modules config-file))
               (when (eq custom-file old-custom-file)
                 (doom-load custom-file 'noerror)))))
         (add-hook 'doom-startup-functions #'doom--startup-modules 80))))))

(provide 'doom-profiles)
;;; doom-profiles.el ends here
