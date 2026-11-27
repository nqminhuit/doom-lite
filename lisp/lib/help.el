;;; lisp/lib/help.el -*- lexical-binding: t; -*-

;;
;;; * Helpers

;;;###autoload
(defun doom-active-minor-modes ()
  "Return a list of active minor-mode symbols."
  (cl-loop for mode in minor-mode-list
           if (and (boundp mode) (symbol-value mode))
           collect mode))

(defun doom--help-insert-button (label &optional uri line)
  "Helper function to insert a button at point.

The button will have the text LABEL. If URI is given, the button will open it,
otherwise the LABEL will be used. If the uri to open is a url it will be opened
in a browser. If LINE is given (and the uri to open is not a url), then the file
will open with point on that line."
  (let ((uri (or uri label)))
    (insert-text-button
     label
     'face 'link
     'follow-link t
     'action
     (if (string-match-p "^https?://" uri)
         (lambda (_) (browse-url uri))
       (unless (file-exists-p uri)
         (error "Path does not exist: %S" uri))
       (lambda (_)
         (when (window-dedicated-p)
           (other-window 1))
         (find-file uri)
         (when line
           (goto-char (point-min))
           (forward-line (1- line))
           (recenter)))))))

(defun doom--help-package-configs (package)
  (let ((default-directory doom-emacs-dir))
    (split-string
     (cdr (doom-call-process
           doom-ripgrep-executable
           "--no-heading" "--line-number" "--iglob" "!*.org"
           (format "%s %s($| )"
                   "(^;;;###package|\\(after!|\\(use-package!)"
                   package)))
     "\n" t)))

(defun doom--help-search-prompt (prompt)
  (let ((query (doom-thing-at-point-or-region)))
    (if (featurep 'counsel)
        query
      (read-string prompt query 'git-grep query))))

(defun doom--help-search (dirs query prompt)
  (unless doom-ripgrep-executable
    (user-error "Can't find ripgrep on your system"))
  (cond ((fboundp 'consult--grep)
         (consult--grep prompt #'consult--ripgrep-make-builder (cons data-directory dirs) query))
        ((fboundp 'counsel-rg)
         (dlet ((counsel-rg-base-command
                 (if (stringp counsel-rg-base-command)
                     (format counsel-rg-base-command
                             (concat "%s " (mapconcat #'shell-quote-argument dirs " ")))
                   (append counsel-rg-base-command dirs))))
           (counsel-rg query nil "-Lz" (concat prompt ": "))))
        ;; TODO: Helm support?
        ((grep-find
          (string-join
           (append (list doom-ripgrep-executable
                         "-L" "--search-zip" "--no-heading" "--color=never"
                         (shell-quote-argument query))
                   (mapcar #'shell-quote-argument dirs))
           " ")))))


;;
;;; * Custom describe commands

;;;###autoload
(defun doom/describe-active-minor-mode (mode)
  "Get information on an active minor mode. Use `describe-minor-mode' for a
selection of all minor-modes, active or not."
  (interactive
   (list
    (completing-read
     "Describe active mode: "
     (lambda (str pred action)
       (if (eq action 'metadata) ; for embark/marginalia
           `(metadata (category . minor-mode))
         (complete-with-action action (doom-active-minor-modes) str pred))))))
  (cl-check-type mode (or string symbol))
  (let ((symbol
         (cond ((stringp mode) (intern mode))
               ((symbolp mode) mode)))
        (fn (if (fboundp symbol) #'describe-function #'describe-variable)))
    (funcall (or (command-remapping fn) fn)
             symbol)))

;;;###autoload
(defun doom/describe-char (event)
  "Like `describe-char', but will operate at mouse point if given prefix arg."
  (interactive
   (list (if current-prefix-arg
             (save-window-excursion
               (message "Click what to describe...")
               (or (when-let* ((evt (read--potential-mouse-event)))
                     ;; Discard mouse release event
                     (read--potential-mouse-event)
                     (cadr evt))
                   (user-error "Aborted")))
           (point))))
  (if (integerp event)
      (describe-char event)
    (when event
      (with-selected-window (posn-window event)
        (describe-char (posn-point event))))))

;;;###autoload
(defun doom/describe-autodef (autodef)
  "Open documentation for an autodef.

An autodef is a Doom concept. It is a function or macro that is always defined,
whether or not its containing module is disabled (in which case it will safely
no-op without evaluating its arguments). This syntactic sugar lets you use them
without needing to check if they are available."
  (interactive
   (let* ((settings
           (cl-loop with case-fold-search = nil
                    for sym being the symbols of obarray
                    for sym-name = (symbol-name sym)
                    if (and (or (functionp sym)
                                (macrop sym))
                            (string-match-p "[a-z]!$" sym-name))
                    collect sym))
          (sym (symbol-at-point))
          (autodef
           (completing-read
            "Describe autodef: "
            ;; REVIEW: Could be cleaner (refactor me!)
            (cl-loop with maxwidth = (apply #'max (mapcar #'length (mapcar #'symbol-name settings)))
                     for def in (sort settings #'string-lessp)
                     if (get def 'doom-module)
                     collect
                     (format (format "%%-%ds%%s" (+ maxwidth 4))
                             def (propertize (format "%s %s" (car it) (cdr it))
                                             'face 'font-lock-comment-face))
                     else if (and (string-match-p "^set-.+!$" (symbol-name def))
                                  (symbol-file def)
                                  (file-in-directory-p (symbol-file def) doom-core-dir))
                     collect
                     (format (format "%%-%ds%%s" (+ maxwidth 4))
                             def (propertize (format "lisp/%s.el" (file-name-sans-extension (file-relative-name (symbol-file def) doom-core-dir)))
                                             'face 'font-lock-comment-face)))
            nil t
            (when (and (symbolp sym)
                       (string-match-p "!$" (symbol-name sym)))
              (symbol-name sym)))))
     (list (and autodef (car (split-string autodef " "))))))
  (or (stringp autodef)
      (functionp autodef)
      (signal 'wrong-type-argument (list '(stringp functionp) autodef)))
  (let ((fn (if (functionp autodef)
                autodef
              (intern-soft autodef))))
    (or (fboundp fn)
        (error "'%s' is not a valid DOOM autodef" autodef))
    (if (fboundp 'helpful-callable)
        (helpful-callable fn)
      (describe-function fn))))

;;;###autoload
(defun doom/describe-module (key)
  "Visit the README.org of module KEY, or dired its directory if it has none."
  (interactive (list (doom-module-completing-read "Describe module: ")))
  (cl-destructuring-bind (_source group module . _flags) key
    (let ((dir (doom-module-locate-path (cons group module))))
      (unless (and dir (file-directory-p dir))
        (user-error "Can't find module %s %s" group module))
      (let ((readme (expand-file-name "README.org" dir)))
        (if (file-exists-p readme)
            (find-file readme)
          (dired dir))))))

;;;###autoload
(defun doom/describe-option (var &optional buffer)
  "Look up documentation for a user option.

Unlike `describe-variable', which casts a wider net that includes internal
variables, this only lists variables that exist to be customized (defined with
`defcustom')."
  (interactive
   (list
    (letf! (defun optionp (sym)
             (and (symbolp sym)
                  (or (get sym 'variable-documentation)
                      (and (boundp sym)
                           (not (keywordp sym))
                           (not (memq sym '(t nil)))))
                  (custom-variable-p sym)
                  ;; Exclude minor mode state variables, which aren't meant to
                  ;; be modified directly, but through their associated
                  ;; function.
                  (not (or (and (string-suffix-p "-mode" (symbol-name sym))
                                (fboundp sym))
                           (eq (get sym 'custom-set) 'custom-set-minor-mode)))))
      (intern (completing-read
               "Describe option: " obarray
               #'optionp t nil nil
               (let ((var (variable-at-point)))
                 ;; `variable-at-point' uses 0 rather than nil to signify no
                 ;; symbol at point (presumably because 'nil is a symbol).
                 (if (optionp var) var)))))))
  (describe-variable var buffer))

(defvar doom--help-packages-list nil)
;;;###autoload
(defun doom/describe-package (package)
  "Like `describe-package', but for packages installed by Doom modules.

Only shows installed packages. Includes information about where packages are
defined and configured.

If prefix arg is present, refresh the cache."
  (interactive
   (let ((guess (or (function-called-at-point)
                    (symbol-at-point))))
     (require 'finder-inf nil t)
     (require 'package)
     (let ((packages
            (if (and doom--help-packages-list (null current-prefix-arg))
                doom--help-packages-list
              (message "Generating packages list for the first time...")
              (redisplay)
              (setq doom--help-packages-list
                    (delete-dups
                     (append (mapcar #'car package--builtins)
                             (mapcar #'car (doom-package-list 'all))
                             nil))))))
       (unless (memq guess packages)
         (setq guess nil))
       (list
        (intern
         (completing-read (format "Describe Doom package (%s): "
                                  (concat (when guess
                                            (format "default '%s', " guess))
                                          (format "total %d" (length packages))))
                          packages nil t nil nil
                          (when guess (symbol-name guess))))))))
  ;; REVIEW: Refactor me.
  (require 'package)
  (require 'finder-inf nil t)
  (doom-initialize-packages)
  (help-setup-xref (list #'doom/describe-package package)
                   (called-interactively-p 'interactive))
  (with-help-window (help-buffer)
    (with-current-buffer standard-output
      (when (and (symbolp package)
                 (assq package package--builtins))
        (describe-package-1 package))
      (let ((indent (make-string 13 ? )))
        (goto-char (point-min))
        (if (re-search-forward "     Status: .*$" nil t)
            (insert "\n")
          (search-forward "\n\n" nil t))

        (package--print-help-section "Package")
        (insert (symbol-name package) "\n")

        (package--print-help-section "Source")
        (pcase (doom-package-backend package)
          (`installed
           (insert "Pinned\n")
           (package--print-help-section "Pin")
           (insert (doom-package-get package :pin) "\n")

           (package--print-help-section "Repo location")
           (let ((repo-dir (doom-packages--repos-dir (doom-package-recipe-repo package))))
             (if (file-exists-p repo-dir)
                 (doom--help-insert-button (abbreviate-file-name repo-dir))
               (insert "n/a"))
             (insert "\n"))

           (package--print-help-section "Build location")
           (let ((build-dir (doom-packages--build-dir package)))
             (if (file-exists-p build-dir)
                 (doom--help-insert-button (abbreviate-file-name build-dir))
               (insert "n/a")))
           (insert "\n")

           (package--print-help-section "Homepage")
           (let ((homepage (doom-package-homepage package)))
             (if homepage
                 (doom--help-insert-button homepage)
               (insert "n/a"))))

          (`builtin (insert "Built-in\n")
                    (package--print-help-section "Location")
                    (doom--help-insert-button
                     (abbreviate-file-name
                      (file-name-directory
                       (locate-library (symbol-name package))))))
          (_ (insert "Not installed")))
        (insert "\n")

        (when-let
            (modules
             (or (doom-package-get package :modules)
                 (plist-get (cdr (assq package (doom-package-list 'all)))
                            :modules)))
          (package--print-help-section "Modules")
          (insert "Declared by the following Doom modules:\n")
          (dolist (m modules)
            (let* ((module-path (pcase (car m)
                                  (:doom doom-core-dir)
                                  (:user doom-user-dir)
                                  (category
                                   (doom-module-locate-path (cons category (cdr m))))))
                   (readme-path (expand-file-name "README.org" module-path)))
              (insert indent)
              (doom--help-insert-button
               (format "%s %s" (car m) (or (cdr m) ""))
               module-path)
              (insert " (")
              (if (file-exists-p readme-path)
                  (doom--help-insert-button "readme" readme-path)
                (insert "no readme"))
              (insert ")\n"))))

        (package--print-help-section "Configs")
        (if-let* ((configs (doom--help-package-configs package)))
            (progn
              (insert "This package is configured in the following locations:")
              (dolist (location configs)
                (insert "\n" indent)
                (cl-destructuring-bind (file line _match &rest)
                    (split-string location ":")
                  (doom--help-insert-button location
                                            (expand-file-name file doom-emacs-dir)
                                            (string-to-number line)))))
          (insert "This package is not configured anywhere"))
        (goto-char (point-min))))))


;;
;;; * Misc help commands

(defvar doom--package-cache nil)
(defun doom--package-list (&optional prompt)
  (require 'package)
  (require 'finder-inf nil t)
  (doom-initialize-packages)
  (let* ((guess (or (function-called-at-point)
                    (symbol-at-point)))
         (packages
          (with-memoization doom--package-cache
            (with-temp-message "Reading packages..."
              (delete-dups
               (append (mapcar #'car doom-packages)
                       (mapcar #'car package--builtins))))))
         (guess (if (memq guess packages) guess)))
    (intern (completing-read (or prompt
                                 (if guess
                                     (format "Select package to search for (default %s): "
                                             guess)
                                   "Describe package: "))
                             packages nil t nil nil
                             (if guess (symbol-name guess))))))

;;;###autoload
(defun doom/help-package-config (package)
  "Jump to any `use-package!', `after!' or ;;;###package block for PACKAGE.

This only searches `doom-emacs-dir' (typically ~/.emacs.d) and does not include
config blocks in your private config."
  (interactive (list (doom--package-list "Find package config: ")))
  (cl-destructuring-bind (file line _match)
      (split-string
       (completing-read
        "Jump to config: "
        (or (doom--help-package-configs package)
            (user-error "This package isn't configured by you or Doom")))
       ":")
    (find-file (expand-file-name file doom-emacs-dir))
    (goto-char (point-min))
    (forward-line (1- line))
    (recenter)))

;;;###autoload
(defun doom/help-package-homepage (package)
  "Open PACKAGE's homepage in a browser."
  (interactive (list (doom--package-list "Visit homepage of: ")))
  (browse-url (doom-package-homepage package)))

;;;###autoload
(defun doom/help-search-load-path (query)
  "Perform a text search on your `load-path'.
Uses the symbol at point or the current selection, if available."
  (interactive
   (list (doom--help-search-prompt "Search load-path: ")))
  (doom--help-search (cl-remove-if-not #'file-directory-p load-path)
                     query "Search load-path: "))

;;;###autoload
(defun doom/help-search-loaded-files (query)
  "Perform a text search on your `load-path'.
Uses the symbol at point or the current selection, if available."
  (interactive
   (list (doom--help-search-prompt "Search loaded files: ")))
  (doom--help-search
   (cl-loop for (file . _) in (cl-remove-if-not #'stringp load-history :key #'car)
            for filebase = (file-name-sans-extension file)
            if (file-exists-p! (or (format "%s.el.gz" filebase)
                                   (format "%s.el" filebase)))
            collect it)
   query "Search loaded files: "))

(provide 'doom-lib '(help))
;;; help.el ends here
