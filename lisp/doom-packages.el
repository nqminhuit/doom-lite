;;; lisp/doom-packages.el -*- lexical-binding: t; -*-
;;; Commentary:
;;
;; Doom's package manager is a small backend of its own: no package.el, no
;; third-party package manager and no recipe repos. Every installed package is declared with
;; `package!', a full-SHA `:pin' and an explicit `:recipe'. 'doom sync' clones
;; each package's repo at its pin under .local/packages/repos/, lays out a build
;; dir per package (symlinks to the files its recipe selects), byte-compiles in
;; dependency order and generates autoloads. The generated profile init puts
;; the build dirs on the `load-path'.
;;
;; Interacting with it is done through Doom's bin/doom script. Highlights:
;;
;; - `doom install': a wizard that guides you through setting up Doom and your
;;   private config for the first time.
;; - `doom sync': your go-to command for making sure Doom is in optimal
;;   condition. It checks out every package at its pin, rebuilds what changed,
;;   removes what is no longer needed and regenerates the profile.
;;
;; How this works is: the system reads packages.el files located in each
;; activated module, your private config (`doom-user-dir'), and one in
;; `doom-core-dir'. These contain `package!' declarations that tell DOOM what
;; packages to install and where from. To bump a package, edit its `:pin' and
;; run 'doom sync'.
;;
;;; Code:

(require 'comp nil t)
(require 'cl-lib)
(require 'doom-modules)


;;
;;; * Variables

;; DEPRECATED: Will be stored in the local profile in v3.0
;;;###autoload
(defvar doom-packages ()
  "A list of enabled packages. Each element is a sublist, whose CAR is the
package's name as a symbol, and whose CDR is the plist supplied to its
`package!' declaration. Set by `doom-initialize-packages'.")

;; DEPRECATED: Will be stored in the local profile in v3.0
;;;###autoload
(defvar doom-disabled-packages ()
  "A list of packages that should be ignored by `use-package!' and `after!'.")

(defvar doom-packages-dir nil
  "Where repos and build dirs live. Defaults to packages/ under `doom-local-dir'.")

(defvar doom-packages-host-urls
  '((github   . "https://github.com/%s.git")
    (codeberg . "https://codeberg.org/%s.git"))
  "Alist mapping a recipe's :host to the format of its remote URL.")

(defconst doom-packages--default-files
  '("*.el" "lisp/*.el"
    (:exclude ".dir-locals.el" "test.el" "tests.el" "*-test.el" "*-tests.el"
              "*-pkg.el" "*-autoloads.el"))
  "The :files a recipe gets when it has none (the .el files of a package, minus tests and generated files).")

(defconst doom-packages--recipe-keys '(:host :repo :files :compile :branch)
  "The keys a recipe may have. :branch is accepted but ignored; the pin decides.")

(defconst doom-packages--remote "origin")

(defconst doom-packages--quiet "--quiet")

(defconst doom-packages--sha-re "\\`[0-9a-fA-F]\\{40\\}\\'")

(defconst doom-packages--state-file ".state.el"
  "Per-package pin, recipe hash and Emacs version, kept in the build root.")

(defconst doom-packages--failed-marker "DOOM-PACKAGES-FAILED "
  "Prefix of the lines a compile child prints for each file that failed.")

(defvar doom-packages--last-failure nil
  "Output of the git command that last made a sync fail, for the CLI error handler.")

(defvar doom-packages--last-build-order nil
  "The packages the last `doom-packages-ensure' rebuilt, in the order it did so.")

(defvar doom-packages--full-fetches nil
  "Repos that needed a full fetch because fetching their pin shallowly failed.")

(defvar doom-packages--eln-output-path (car (bound-and-true-p native-comp-eln-load-path)))


;;
;;; * Library

(defun doom-packages--dir ()
  (or doom-packages-dir
      (file-name-concat (file-truename doom-local-dir) "packages/")))

(defun doom-packages--repos-dir (&optional repo)
  (file-name-concat (doom-packages--dir) "repos" repo))

(defun doom-packages--build-root ()
  "The build root for this Emacs version, with a trailing slash."
  (file-name-concat (doom-packages--dir) (format "build-%s" emacs-version) ""))

(defun doom-packages--build-dir (package)
  (file-name-concat (doom-packages--build-root) (format "%s" package)))

(defun doom-packages--autoloads-file (package)
  (file-name-concat (doom-packages--build-dir package)
                    (format "%s-autoloads.el" package)))

(defun doom-packages--declared-in (package)
  (or (doom-package-get package :declared-in) "an unknown packages.el"))

(defun doom-packages--error (package fmt &rest args)
  "Signal a `doom-package-error' naming PACKAGE and the packages.el declaring it."
  (signal 'doom-package-error
          (list (format "%s" package)
                (format "%s (declared in %s)" (apply #'format fmt args)
                        (doom-packages--declared-in package)))))

(defun doom-packages--installed ()
  "Names of the declared packages Doom installs, in declaration order."
  (cl-loop for (name . plist) in doom-packages
           unless (or (plist-get plist :ignore) (plist-get plist :disable))
           collect name))

(defun doom-packages--check-built ()
  (dolist (name (doom-packages--installed))
    (unless (file-directory-p (doom-packages--build-dir name))
      (user-error "Package state is incomplete. Run 'doom sync' first"))))


;;; ** Recipes and stage-1 rules

(defun doom-packages--normalize-recipe (recipe)
  (list :host (or (plist-get recipe :host) 'github)
        :repo (plist-get recipe :repo)
        :files (if (plist-member recipe :files)
                   (plist-get recipe :files)
                 doom-packages--default-files)
        :compile (if (plist-member recipe :compile) (plist-get recipe :compile) t)))

(defun doom-packages--check-files (package files)
  (unless (proper-list-p files)
    (doom-packages--error package "recipe :files must be a list"))
  (dolist (item files)
    (unless (or (stringp item) (eq item :defaults)
                (and (eq (car-safe item) :exclude)
                     (proper-list-p item)
                     (cl-every #'stringp (cdr item))))
      (doom-packages--error package "invalid recipe :files entry %S" item))))

(defun doom-packages--check-recipe (package recipe)
  (unless (and recipe (proper-list-p recipe) (cl-evenp (length recipe)))
    (doom-packages--error package "needs a :recipe with at least :repo"))
  (cl-loop for (key _) on recipe by #'cddr
           unless (memq key doom-packages--recipe-keys)
           do (doom-packages--error package "unknown recipe key %S" key))
  (let ((host (or (plist-get recipe :host) 'github))
        (repo (plist-get recipe :repo)))
    (unless (assq host doom-packages-host-urls)
      (doom-packages--error package "unknown recipe :host %S" host))
    (unless (and (stringp repo) (string-match-p "\\`[^/ ]+/[^/ ]+\\'" repo))
      (doom-packages--error package "recipe :repo must be \"owner/name\", got %S" repo)))
  (doom-packages--check-files package (plist-get (doom-packages--normalize-recipe recipe) :files)))

(defun doom-packages--check-declarations ()
  "Stage 1: check every installed package's pin and recipe. Touches no network."
  (let (repos)
    (dolist (name (doom-packages--installed))
      (let ((pin (doom-package-get name :pin))
            (recipe (doom-package-get name :recipe)))
        (unless (and (stringp pin) (string-match-p doom-packages--sha-re pin))
          (doom-packages--error name "needs a full 40-character :pin, got %S" pin))
        (doom-packages--check-recipe name recipe)
        (let* ((repo (plist-get recipe :repo))
               (key (file-name-nondirectory repo))
               (seen (cdr (assoc key repos)))
               (id (format "%s:%s" (or (plist-get recipe :host) 'github) repo)))
          (cond ((null seen) (push (list key id (downcase pin) name) repos))
                ((not (equal (car seen) id))
                 (doom-packages--error
                  name "repo %s clashes with %s's (both are cloned into repos/%s)"
                  id (nth 2 seen) key))
                ((not (equal (cadr seen) (downcase pin)))
                 (doom-packages--error
                  name "shares repo %s with %s but pins a different commit" repo (nth 2 seen)))))))))

(defun doom-packages--repos ()
  "Alist of (REPO-NAME . PLIST) for the repos the installed packages need.
PLIST has :remote, :pin and :packages."
  (let (repos)
    (dolist (name (doom-packages--installed))
      (let* ((recipe (doom-package-recipe name))
             (key (file-name-nondirectory (plist-get recipe :repo)))
             (entry (or (assoc key repos)
                        (car (push (cons key
                                         (list :remote (format (alist-get (plist-get recipe :host)
                                                                          doom-packages-host-urls)
                                                               (plist-get recipe :repo))
                                               :pin (downcase (doom-package-get name :pin))))
                                   repos)))))
        (setcdr entry (plist-put (cdr entry) :packages
                                 (append (plist-get (cdr entry) :packages) (list name))))))
    (nreverse repos)))


;;; ** Git

(defmacro doom-packages--with-git-env (&rest body)
  "Run BODY with user and system git config ignored and git prompts disabled."
  (declare (indent 0))
  `(with-environment-variables
       (("GIT_CONFIG" nil)
        ("GIT_CONFIG_NOSYSTEM" "1")
        ("GIT_CONFIG_GLOBAL" (or (getenv "DOOMGITCONFIG") "/dev/null"))
        ("GIT_TERMINAL_PROMPT" "0"))
     ,@body))

(defun doom-packages--git (dir &rest args)
  "Run git ARGS in DIR with user and system git config ignored.
Returns (STATUS . OUTPUT)."
  (let ((default-directory (file-name-as-directory dir)))
    (doom-packages--with-git-env
      (with-temp-buffer
        (let ((status (apply #'call-process "git" nil t nil args)))
          (doom-log "packages:git: git %s -> %s" (string-join args " ") status)
          (cons status (string-trim-right (buffer-string))))))))

(defun doom-packages--git! (package dir &rest args)
  "Like `doom-packages--git', but signal an error naming PACKAGE if git fails."
  (let ((result (apply #'doom-packages--git dir args)))
    (unless (zerop (car result))
      (setq doom-packages--last-failure
            (format "$ git %s\n%s" (string-join args " ") (cdr result)))
      (doom-packages--error package "git %s failed" (car args)))
    (cdr result)))

(defun doom-packages--head (dir)
  (when (file-directory-p (file-name-concat dir ".git"))
    (let ((result (doom-packages--git dir "rev-parse" "HEAD")))
      (and (zerop (car result)) (downcase (cdr result))))))

(defun doom-packages--checkout (repo plist)
  "Bring REPO's checkout to its pin. Return the old HEAD (or t if newly cloned), or nil if unchanged."
  (let* ((dir (doom-packages--repos-dir repo))
         (pin (plist-get plist :pin))
         (package (car (plist-get plist :packages)))
         (remote (plist-get plist :remote))
         (head (doom-packages--head dir))
         done)
    (unless (equal head pin)
      (unwind-protect
          (progn
            (unless head
              (when (file-exists-p dir) (delete-directory dir t))
              (make-directory dir t)
              (doom-packages--git! package dir "init" doom-packages--quiet)
              (doom-packages--git! package dir "remote" "add" doom-packages--remote remote))
            (when head
              (doom-packages--git! package dir "remote" "set-url" doom-packages--remote remote))
            (unless (and (zerop (car (doom-packages--git dir "fetch" doom-packages--quiet "--depth" "1"
                                                         "--no-tags" doom-packages--remote pin)))
                         (zerop (car (doom-packages--git dir "checkout" doom-packages--quiet "--detach"
                                                         "FETCH_HEAD"))))
              (cl-pushnew repo doom-packages--full-fetches :test #'equal)
              (doom-packages--git! package dir "fetch" doom-packages--quiet doom-packages--remote)
              (doom-packages--git! package dir "checkout" doom-packages--quiet "--detach" pin))
            (let ((actual (doom-packages--head dir)))
              (unless (equal actual pin)
                (doom-packages--error package "repos/%s is at %s after checkout, not its pin %s"
                                      repo actual pin)))
            (setq done t)
            (or head t))
        ;; Never leave a half-made clone behind; later syncs would trust it.
        (unless (or done head)
          (ignore-errors (delete-directory dir t)))))))


;;; ** Files, dependencies and build

(defun doom-packages--glob (dir patterns)
  (let ((default-directory (file-name-as-directory dir)))
    (cl-loop for pattern in patterns
             append (cl-remove-if (lambda (f) (string-prefix-p "." (file-name-nondirectory f)))
                                  (file-expand-wildcards pattern)))))

(defun doom-packages--dir-files (dir relative)
  "All files under DIR (but not .git) as (SOURCE . DEST), DEST starting with RELATIVE."
  (cl-loop for file in (directory-files-recursively dir "" nil
                                                    (lambda (d) (not (equal (file-name-nondirectory (directory-file-name d)) ".git"))))
           collect (cons file (file-name-concat relative (file-relative-name file dir)))))

(defun doom-packages--files (package)
  "The files PACKAGE's recipe selects, as ((SOURCE . DEST) ...), DEST relative to its build dir."
  (let* ((recipe (doom-package-recipe package))
         (repo-dir (file-name-as-directory
                    (doom-packages--repos-dir (doom-package-recipe-repo package))))
         includes excludes files)
    (cl-labels ((walk (items)
                  (dolist (item items)
                    (cond ((eq item :defaults) (walk doom-packages--default-files))
                          ((stringp item) (push item includes))
                          ((eq (car-safe item) :exclude)
                           (setq excludes (append excludes (cdr item))))))))
      (walk (plist-get recipe :files)))
    (let ((excluded (doom-packages--glob repo-dir excludes)))
      (dolist (path (cl-remove-duplicates (doom-packages--glob repo-dir (nreverse includes))
                                          :test #'equal))
        (unless (member path excluded)
          (let ((source (expand-file-name path repo-dir))
                (dest (file-name-nondirectory path)))
            (dolist (entry (if (file-directory-p source)
                               (doom-packages--dir-files source dest)
                             (list (cons source dest))))
              (when-let* ((clash (assoc (cdr entry) files)))
                (unless (equal (car clash) (car entry))
                  (doom-packages--error package "files %s and %s both land at %s"
                                        (file-relative-name (car clash) repo-dir)
                                        (file-relative-name (car entry) repo-dir)
                                        (cdr entry))))
              (push entry files))))))
    (nreverse files)))

(defun doom-packages--main-file (package)
  "PACKAGE's built <package>.el, if it has been built."
  (let ((built (file-name-concat (doom-packages--build-dir package) (format "%s.el" package))))
    (and (file-exists-p built) built)))

(defun doom-packages--main-file-source (package files)
  "The checkout file that becomes PACKAGE's <package>.el, among FILES ((SOURCE . DEST) ...)."
  (car (rassoc (format "%s.el" package) files)))

(defun doom-packages--file-requires (file)
  "The Package-Requires of FILE as ((NAME VERSION-LIST) ...)."
  (require 'lisp-mnt)
  (with-temp-buffer
    (insert-file-contents file)
    (lm-package-requires)))

(defun doom-packages--emacs-library-p (library)
  (locate-library (symbol-name library) nil
                  (seq-remove (lambda (dir) (file-in-directory-p dir (doom-packages--dir)))
                              (or (get 'load-path 'initial-value) load-path))))

(defun doom-packages--builtin-version (package)
  (require 'package)
  (require 'finder-inf nil t)
  (when-let* ((entry (assq package (bound-and-true-p package--builtins))))
    (aref (cdr entry) 0)))

(defun doom-packages--check-requirement (package dep version)
  "Stage 2: check PACKAGE's requirement DEP >= VERSION. Return DEP if it is an installed package."
  (let* ((declared (assq dep doom-packages))
         (version (cond ((stringp version) (version-to-list version))
                        (version)
                        ('(0))))
         (want (mapconcat #'number-to-string version ".")))
    (cond
     ((eq dep 'emacs)
      (when (version-list-< (version-to-list emacs-version) version)
        (doom-packages--error package "needs Emacs %s, this is %s" want emacs-version))
      nil)
     ((and declared (plist-get (cdr declared) :disable))
      (doom-packages--error package "depends on %s, which is disabled" dep))
     ((and declared (not (plist-get (cdr declared) :ignore)))
      dep)
     ((or (and declared (plist-get (cdr declared) :built-in))
          (doom-packages--emacs-library-p dep))
      (let ((have (doom-packages--builtin-version dep)))
        (when (and have (version-list-< have version))
          (doom-packages--error package "needs %s %s but Emacs provides %s"
                                dep want (mapconcat #'number-to-string have "."))))
      nil)
     (declared
      (doom-packages--error package "depends on %s, which is ignored and not part of Emacs" dep))
     (t (doom-packages--error package "depends on %s, which is not declared (add a package! for it)"
                              dep)))))

(defun doom-packages--direct-deps (package)
  "Installed packages that PACKAGE's built main file requires."
  (when-let* ((file (doom-packages--main-file package)))
    (let ((installed (doom-packages--installed)))
      (cl-loop for (dep _) in (doom-packages--file-requires file)
               if (memq dep installed) collect dep))))

(defun doom-packages--toposort (packages deps-fn)
  "Order PACKAGES with dependencies first. DEPS-FN maps a package to its dependencies."
  (let (order done stack)
    (cl-labels ((visit (pkg)
                  (cond ((memq pkg done))
                        ((memq pkg stack)
                         (doom-packages--error
                          pkg "dependency cycle: %s"
                          (mapconcat #'symbol-name (append (memq pkg (reverse stack)) (list pkg)) " -> ")))
                        (t (push pkg stack)
                           (mapc #'visit (funcall deps-fn pkg))
                           (pop stack)
                           (push pkg done)
                           (push pkg order)))))
      (mapc #'visit packages))
    (nreverse order)))

(defun doom-packages--transitive-deps (package graph)
  (let (seen)
    (cl-labels ((walk (pkg)
                  (dolist (dep (alist-get pkg graph))
                    (unless (memq dep seen)
                      (push dep seen)
                      (walk dep)))))
      (walk package))
    (nreverse seen)))

(defun doom-packages--plan ()
  "Stage 2: read each installed package's requirements from its files and check them.
Returns ((PACKAGE :files FILES :deps DEPS) ...) in build order."
  (let (info)
    (dolist (package (doom-packages--installed))
      (let* ((files (doom-packages--files package))
             (main (doom-packages--main-file-source package files)))
        (unless main
          (doom-packages--error package "its recipe selects no %s.el" package))
        (let (deps)
          (dolist (req (doom-packages--file-requires main))
            (when-let* ((dep (doom-packages--check-requirement package (car req) (cadr req))))
              (cl-pushnew dep deps)))
          (push (list package :files files :deps (nreverse deps)) info))))
    (setq info (nreverse info))
    (mapcar (lambda (package) (assq package info))
            (doom-packages--toposort (mapcar #'car info)
                                     (lambda (pkg) (plist-get (cdr (assq pkg info)) :deps))))))

(defun doom-packages--link-files (build-dir files)
  (dolist (file files)
    (let ((dest (expand-file-name (cdr file) build-dir)))
      (make-directory (file-name-directory dest) t)
      (make-symbolic-link (car file) dest))))

(defun doom-packages--byte-compile (package load-dirs)
  "Byte-compile PACKAGE's build dir in a clean child Emacs. Return the files that failed."
  (let* ((dir (doom-packages--build-dir package))
         (form `(progn
                  (setq load-path (append ',load-dirs load-path)
                        native-comp-jit-compilation nil)
                  (let (failed)
                    (dolist (file (directory-files-recursively ,dir "\\.el\\'"))
                      (unless (condition-case err
                                  (byte-compile-file file)
                                (error (princ (format "Error: %S\n" err)) nil))
                        (push file failed)
                        (princ (format "%s%s\n" ,doom-packages--failed-marker file))))
                    (kill-emacs (if failed 1 0)))))
         (print-length nil)
         (print-level nil)
         (status nil)
         (output (with-temp-buffer
                   (setq status (call-process (expand-file-name invocation-name invocation-directory)
                                              nil t nil "--batch" "-Q" "--eval" (prin1-to-string form)))
                   (buffer-string)))
         failed)
    (doom-log "packages:compile: %s\n%s" package output)
    (dolist (line (split-string output "\n" t))
      (when (string-prefix-p doom-packages--failed-marker line)
        (push (substring line (length doom-packages--failed-marker)) failed)))
    ;; The child died before reporting (e.g. it could not start): count the whole package.
    (when (and (not failed) (not (eql status 0)))
      (push dir failed))
    (when failed
      (print! (error "%s: failed to byte-compile %d file(s)") package (length failed))
      (print-group!
        (dolist (file (nreverse (copy-sequence failed)))
          (print! (item "%s") (file-relative-name file dir)))
        (dolist (line (seq-take (seq-filter (lambda (l) (string-match-p "[Ee]rror" l))
                                            (split-string output "\n" t))
                                8))
          (print! "%s" line))))
    (nreverse failed)))

(define-advice loaddefs-generate--parse-file (:around (fn &rest args) inhibit-emacs-lisp-mode)
  "Don't run `emacs-lisp-mode-hook' while scraping files.
Some packages add hooks to it from their autoloads that load their dependencies."
  (let (emacs-lisp-mode-hook)
    (apply fn args)))

(defun doom-packages--generate-autoloads (package)
  "Write <package>-autoloads.el from the top-level .el files in PACKAGE's build dir."
  (require 'loaddefs-gen)
  (let ((autoload-compute-prefixes nil))
    (quiet! (loaddefs-generate (doom-packages--build-dir package)
                               (doom-packages--autoloads-file package)))))

(defun doom-packages--build (package files load-dirs recipe)
  "Recreate PACKAGE's build dir from FILES and build it. Return the files that failed to compile."
  (let ((dir (doom-packages--build-dir package)))
    (delete-directory dir t)
    (make-directory dir t)
    (doom-packages--link-files dir files)
    (let ((failed (when (plist-get recipe :compile)
                    (doom-packages--byte-compile package (cons dir load-dirs)))))
      (condition-case-unless-debug err
          (doom-packages--generate-autoloads package)
        (error
         (print! (error "%s: failed to generate autoloads: %s") package (error-message-string err))
         (push (doom-packages--autoloads-file package) failed)))
      failed)))


;;; ** State

(defun doom-packages--read-state ()
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents (file-name-concat (doom-packages--build-root) doom-packages--state-file))
      (read (current-buffer)))))

(defun doom-packages--write-state (state)
  (make-directory (doom-packages--build-root) t)
  (with-temp-file (file-name-concat (doom-packages--build-root) doom-packages--state-file)
    (let ((print-length nil) (print-level nil))
      (insert ";; -*- lisp-data -*-\n")
      (prin1 state (current-buffer))
      (insert "\n"))))

(defun doom-packages--state-entry (package)
  (list package
        :pin (downcase (doom-package-get package :pin))
        :recipe (secure-hash 'sha1 (prin1-to-string (doom-package-recipe package)))
        :emacs emacs-version))


;;
;;; * Public API

;;;###autoload
(defun doom-initialize-packages (&optional force-p)
  "Process all packages, if they haven't already been.

If FORCE-P is non-nil, do it anyway.

This ensures `doom-packages' is populated and valid, and puts the build dirs of
the installed packages on the `load-path'."
  (when (or force-p (null doom-packages))
    (doom-log "Initializing packages")
    (setq doom-disabled-packages nil
          doom-packages (doom-package-list))
    (doom-packages--check-declarations)
    (dolist (package doom-packages)
      (when (plist-get (cdr package) :disable)
        (cl-pushnew (car package) doom-disabled-packages)))
    (dolist (name (doom-packages--installed))
      (add-to-list 'load-path (directory-file-name (doom-packages--build-dir name))))))

;;;###autoload
(defun doom-package-get (package &optional prop nil-value)
  "Returns PACKAGE's `package!' recipe from `doom-packages'."
  (let ((plist (cdr (assq package doom-packages))))
    (if prop
        (if (plist-member plist prop)
            (plist-get plist prop)
          nil-value)
      plist)))

;;;###autoload
(defun doom-package-set (package prop value)
  "Set PROPERTY in PACKAGE's recipe to VALUE."
  (setf (alist-get package doom-packages)
        (plist-put (alist-get package doom-packages)
                   prop value)))

;;;###autoload
(defun doom-package-recipe (package &optional prop nil-value)
  "Return PACKAGE's recipe with defaults filled in, or nil if it has none."
  (let ((plist (when-let* ((recipe (doom-package-get package :recipe)))
                 (doom-packages--normalize-recipe recipe))))
    (if prop
        (if (plist-member plist prop)
            (plist-get plist prop)
          nil-value)
      plist)))

;;;###autoload
(defun doom-package-recipe-repo (package)
  "Return the name of the repo dir PACKAGE is cloned into."
  (if-let* ((repo (doom-package-recipe package :repo)))
      (file-name-nondirectory repo)
    (symbol-name package)))

;;;###autoload
(defun doom-package-dependencies (package &optional recursive _noerror)
  "Return the installed packages PACKAGE depends on, read from its built files.

If RECURSIVE is `tree', return a tree of dependencies.
If RECURSIVE is t, return all of them, flattened.
If RECURSIVE is nil, only return PACKAGE's immediate dependencies."
  (cl-check-type package symbol)
  (let ((deps (doom-packages--direct-deps package)))
    (pcase recursive
      (`tree (mapcar (lambda (dep) (cons dep (doom-package-dependencies dep 'tree))) deps))
      (`t (delete-dups (cl-loop for dep in deps
                                append (cons dep (doom-package-dependencies dep t)))))
      (_ deps))))

;;; Predicate functions
;;;###autoload
(defun doom-package-built-in-p (package)
  "Return non-nil if PACKAGE (a symbol) was declared `:built-in'."
  (and (doom-package-get package :built-in) t))

;;;###autoload
(defun doom-package-installed-p (package)
  "Return non-nil if PACKAGE (a symbol) is installed (has been built)."
  (and (not (doom-package-get package :ignore))
       (not (doom-package-get package :disable))
       (file-directory-p (doom-packages--build-dir package))))

;;;###autoload
(defun doom-package-in-module-p (package category &optional module)
  "Return non-nil if PACKAGE was installed by the user's private config."
  (when-let* ((modules (doom-package-get package :modules)))
    (or (and (not module) (assq :user modules))
        (member (cons category module) modules))))



;;;###autoload
(defun doom-package-backend (package)
  "Return \\='installed, \\='builtin or nil, depending on how PACKAGE is provided."
  (cond ((doom-package-installed-p package) 'installed)
        ((or (doom-package-built-in-p package)
             (assq package (bound-and-true-p package--builtins)))
         'builtin)))

;;; ** Package getters

(defun doom-packages--read (file &optional noeval noerror)
  (condition-case-unless-debug e
      (with-temp-buffer ; prevent buffer-local state from propagating
        (if (not noeval)
            (load file noerror 'nomessage 'nosuffix)
          (when (file-exists-p file)
            (insert-file-contents file)
            (with-syntax-table emacs-lisp-mode-syntax-table
              ;; Scrape `package!' blocks from FILE for a comprehensive listing of
              ;; packages used by this module.
              (while (search-forward "(package!" nil t)
                (let ((ppss (save-excursion (syntax-ppss))))
                  ;; Don't collect packages in comments or strings
                  (unless (or (nth 3 ppss)
                              (nth 4 ppss))
                    (goto-char (match-beginning 0))
                    (cl-destructuring-bind (_ name . plist)
                        (read (current-buffer))
                      (push (cons
                             name (plist-put
                                   plist :modules
                                   (list (doom-module-context-key doom-module-context))))
                            doom-packages)))))))))
    (user-error
     (user-error (error-message-string e)))
    (error
     (signal 'doom-package-error
             (list (doom-module-context-key doom-module-context)
                   file e)))))

;;;###autoload
(defun doom-package-list (&optional module-list)
  "Retrieve a list of explicitly declared packages from MODULE-LIST.

If MODULE-LIST is omitted, read enabled module list in configdepth order (see
`doom-module-set'). Otherwise, MODULE-LIST may be any symbol (or t) to mean read
all modules, including :doom and :user. MODULE-LIST may also be a list of module
keys."
  (let ((module-list (cond ((null module-list) (doom-module-list))
                           ((symbolp module-list) (doom-module-list 'all))
                           (module-list)))
        doom-disabled-packages
        doom-packages)
    (letf! (defun read-packages (key)
             (with-doom-module key
               (when-let* ((file (or (doom-module-expand-path
                                      key doom-module-packages-file)
                                     (doom-module-locate-path
                                      key doom-module-packages-file))))
                 (doom-packages--read file nil 'noerror))))
      (with-doom-context 'package
        (let ((user? (assq :user module-list)))
          (when user?
            ;; We load the private packages file twice to populate
            ;; `doom-disabled-packages' disabled packages are seen ASAP...
            (let (doom-packages)
              (read-packages (cons :user nil))))
          (mapc #'read-packages module-list)
          ;; ...Then again to ensure privately overriden packages are properly
          ;; overwritten.
          (if user? (read-packages (cons :user nil)))
          (nreverse doom-packages))))))


;;;###autoload
(defun doom-package-pinned-alist ()
  "Return an alist mapping repo names (strings) to pinned commits (strings)."
  (let (alist)
    (dolist (package doom-packages (nreverse alist))
      (cl-destructuring-bind (name &key disable ignore pin &allow-other-keys)
          package
        (when (and pin (not ignore) (not disable))
          (setf (alist-get (doom-package-recipe-repo name) alist nil nil #'equal)
                pin))))))

;;;###autoload
(defun doom-package-homepage (package)
  "Return the url to PACKAGE's homepage (usually a repo)."
  (doom-initialize-packages)
  (or (get package 'homepage)
      (put package 'homepage
           (or (when-let* ((repo (doom-package-recipe package :repo)))
                 (format "https://%s/%s"
                         (pcase (doom-package-recipe package :host)
                           ('codeberg "codeberg.org")
                           (_ "github.com"))
                         repo))
               (when-let* ((location (locate-library (symbol-name package))))
                 (with-temp-buffer
                   (if (string-match-p "\\.gz$" location)
                       (jka-compr-insert-file-contents location)
                     (insert-file-contents (concat (file-name-sans-extension location) ".el")
                                           nil 0 4096))
                   (let ((case-fold-search t))
                     (when (re-search-forward " \\(?:url\\|homepage\\|website\\): \\(http[^\n]+\\)\n" nil t)
                       (match-string-no-properties 1)))))
               (user-error "Can't get homepage for %S package" package)))))


;;
;;; * CLI API

(defun doom-packages--require-git ()
  (unless (executable-find "git")
    (user-error "Git isn't present on your system. Cannot proceed.")))

(defun doom-packages--abbrev (commit)
  (substring commit 0 7))

;;;###autoload
(defun doom-packages-update ()
  "Bring every package's repo to its pin, cloning what is missing.
Returns the names of the repos that were cloned or moved."
  (doom-initialize-packages)
  (doom-packages--check-declarations)
  (doom-packages--require-git)
  (let* ((repos (doom-packages--repos))
         (total (length repos))
         moved)
    (setq doom-packages--full-fetches nil
          doom-packages--last-failure nil)
    (if (not (file-directory-p (doom-packages--repos-dir)))
        (print! (start "Cloning %d repos at their pins (this may take a while)...") total)
      (print! (start "Checking %d repos are at their pins..." total)))
    (print-group!
      (pcase-dolist (`(,repo . ,plist) repos)
        (when-let* ((old (doom-packages--checkout repo plist)))
          (push repo moved)
          (print! (item "%s: %s%s") repo
                  (if (stringp old) (concat (doom-packages--abbrev old) " -> ") "pinned to ")
                  (doom-packages--abbrev (plist-get plist :pin)))))
      (when doom-packages--full-fetches
        (print! (warn "%d repo(s) needed a full fetch: %s")
                (length doom-packages--full-fetches)
                (string-join (reverse doom-packages--full-fetches) ", "))))
    (nreverse moved)))

(defun doom-packages--needs-build-p (package state info built force-p)
  (or force-p
      (not (file-directory-p (doom-packages--build-dir package)))
      (not (equal (cdr (assq package state)) (cdr (doom-packages--state-entry package))))
      (cl-some (lambda (dep) (memq dep built)) (plist-get (cdr info) :deps))))

;;;###autoload
(defun doom-packages-migrate-straight ()
  "Delete the old straight tree (.local/straight/) and .local/elpa/, if present."
  (let ((straight-dir (file-name-concat doom-local-dir "straight/"))
        (elpa-dir (file-name-concat doom-local-dir "elpa/")))
    (when (file-exists-p (directory-file-name straight-dir))
      (print! (item "Replacing the old straight tree under %s") (path straight-dir))
      (dolist (dir (list straight-dir elpa-dir))
        (when (file-exists-p (directory-file-name dir))
          (delete-directory dir t))))))

;;;###autoload
(defun doom-packages-ensure (&optional force-p)
  "Check every repo out at its pin, then (re)build the packages that need it.

A package is rebuilt when its pin, recipe or the Emacs version changed, when a
dependency was rebuilt, or when FORCE-P is non-nil. Returns the packages that
failed to byte-compile."
  (doom-packages-migrate-straight)
  (doom-packages-update)
  (let* ((plan (doom-packages--plan))
         (graph (mapcar (lambda (info) (cons (car info) (plist-get (cdr info) :deps))) plan))
         (state (doom-packages--read-state))
         (new-state (seq-filter (lambda (entry) (assq (car entry) graph)) state))
         built failed)
    (setq doom-packages--last-build-order nil)
    (unwind-protect
        (dolist (info plan)
          (let ((package (car info)))
            (when (doom-packages--needs-build-p package state info built force-p)
              (print! (start "Building %s...") package)
              (let* ((deps (doom-packages--transitive-deps package graph))
                     (bad (doom-packages--build
                           package (plist-get (cdr info) :files)
                           (mapcar #'doom-packages--build-dir deps)
                           (doom-package-recipe package))))
                (push package built)
                (push package doom-packages--last-build-order)
                (setq new-state (assq-delete-all package new-state))
                (if bad
                    (push package failed)
                  (push (doom-packages--state-entry package) new-state))))))
      (doom-packages--write-state new-state)
      (setq doom-packages--last-build-order (nreverse doom-packages--last-build-order)))
    (if built
        (print! (success "Built %d package(s)") (length built))
      (print! (item "No packages need attention")))
    (nreverse failed)))

(defun doom-packages--stale-dirs ()
  "Dirs under `doom-packages--dir' that the declared packages no longer use.
Returns (:repos DIRS :builds DIRS)."
  (let* ((used-repos (mapcar #'car (doom-packages--repos)))
         (used-builds (mapcar #'symbol-name (doom-packages--installed)))
         (root (directory-file-name (doom-packages--build-root)))
         (list-dirs (lambda (dir &optional keep)
                      (when (file-directory-p dir)
                        (seq-filter (lambda (path)
                                      (and (file-directory-p path)
                                           (not (member (file-name-nondirectory path) keep))))
                                    (directory-files dir t "\\`[^.]"))))))
    (list :repos (funcall list-dirs (doom-packages--repos-dir) used-repos)
          :builds (append
                   (funcall list-dirs root used-builds)
                   ;; Byte-code from other Emacs versions is unusable.
                   (seq-remove (lambda (path) (file-equal-p path root))
                               (seq-filter (lambda (path) (string-prefix-p "build-" (file-name-nondirectory path)))
                                           (funcall list-dirs (doom-packages--dir))))))))

;;;###autoload
(defun doom-packages-gc (&optional norepos-p nobuilds-p)
  "Delete the repos and build dirs the declared packages don't use.
Includes build dirs of other Emacs versions. Returns the number of dirs deleted."
  (doom-initialize-packages)
  (let* ((stale (doom-packages--stale-dirs))
         (dirs (append (unless norepos-p (plist-get stale :repos))
                       (unless nobuilds-p (plist-get stale :builds))))
         (base (doom-packages--dir)))
    (dolist (dir dirs)
      (delete-directory dir t)
      (print! (success "Purged %s") (file-relative-name dir base)))
    (when dirs
      (doom-packages--write-state
       (seq-filter (lambda (entry) (file-directory-p (doom-packages--build-dir (car entry))))
                   (doom-packages--read-state))))
    (length dirs)))


;;; ** Bumping pins

(defconst doom-packages--bump-jobs 8
  "How many `git ls-remote' processes `doom-packages-bump' runs at once.")

(defconst doom-packages--version-comment-re ";+ *v?[0-9]+\\(\\.[0-9]+\\)+"
  "A trailing comment that records a package's version, which a bump makes stale.")

(defun doom-packages--ls-remote-all (jobs)
  "Run (KEY REMOTE REF) JOBS in parallel; return an alist of (KEY SHA . ERROR).
SHA is nil, with ERROR set, if REF could not be resolved."
  (let ((queue (copy-sequence jobs))
        (running 0)
        results)
    (cl-labels
        ((finish (key ref buf status)
           (let* ((out (with-current-buffer buf (buffer-string)))
                  (sha (and (eq status 0)
                            (cl-loop for line in (split-string out "\n" t)
                                     for (id name) = (split-string line "\t")
                                     if (and (equal name ref) (string-match-p "\\`[0-9a-f]\\{40\\}\\'" id))
                                     return (downcase id)))))
             (kill-buffer buf)
             (push (cons key (cons sha (unless sha
                                         (if (eq status 0)
                                             (format "%s not found" ref)
                                           (string-trim out)))))
                   results)
             (cl-decf running)
             (start-next)))
         (start-next ()
           (while (and queue (< running doom-packages--bump-jobs))
             (pcase-let* ((`(,key ,remote ,ref) (pop queue))
                          (buf (generate-new-buffer " *doom-ls-remote*")))
               (cl-incf running)
               (doom-packages--with-git-env
                 (make-process
                  :name "doom-ls-remote" :buffer buf :noquery t
                  :connection-type 'pipe
                  :command (list "git" "ls-remote" remote ref)
                  :sentinel (lambda (proc _event)
                              (unless (process-live-p proc)
                                (finish key ref buf (process-exit-status proc))))))))))
      (start-next)
      (while (> running 0)
        (accept-process-output nil 0.05)))
    results))

(defun doom-packages--package-files ()
  "The packages.el files `doom-package-list' reads, in load order."
  (cl-loop for key in (doom-module-list)
           for file = (or (doom-module-expand-path key doom-module-packages-file)
                          (doom-module-locate-path key doom-module-packages-file))
           if (and file (file-exists-p file)) collect file))

(defun doom-packages--find-pin-form (package)
  "Return (FILE BEG END) of the last `package!' form of PACKAGE that sets :pin."
  (let (found)
    (dolist (file (doom-packages--package-files))
      (with-temp-buffer
        (insert-file-contents file)
        (with-syntax-table emacs-lisp-mode-syntax-table
          (while (search-forward "(package!" nil t)
            (let ((ppss (save-excursion (syntax-ppss))))
              (unless (or (nth 3 ppss) (nth 4 ppss))
                (goto-char (match-beginning 0))
                (let* ((beg (point))
                       (form (condition-case nil (read (current-buffer))
                               (error (goto-char (1+ beg)) nil))))
                  (when (and (consp form)
                             (eq (car-safe (cdr form)) package)
                             (plist-member (cddr form) :pin))
                    (setq found (list file beg (point)))))))))))
    found))

(defun doom-packages--rewrite-pin (package old new)
  "Replace PACKAGE's pin OLD with NEW in the file that sets it; return that file.
Also drops a trailing version comment on the pin's line, which would go stale."
  (pcase-let ((`(,file ,beg ,end) (or (doom-packages--find-pin-form package)
                                      (user-error "Cannot find where %s sets its :pin" package))))
    (let ((coding-system-for-read 'utf-8-unix)
          (coding-system-for-write 'utf-8-unix)
          (case-fold-search t))
      (with-temp-buffer
        (insert-file-contents file)
        (with-syntax-table emacs-lisp-mode-syntax-table
          (goto-char beg)
          (unless (search-forward (format "\"%s\"" old) end t)
            (user-error "%s's :pin in %s is not the literal %s" package file old))
          (replace-match (format "\"%s\"" new) t t)
          (when (re-search-forward (concat "[ \t]*\\(" doom-packages--version-comment-re "\\)")
                                   (line-end-position) t)
            (when (nth 4 (syntax-ppss (1+ (match-beginning 1))))
              (delete-region (match-beginning 0) (line-end-position)))))
        (write-region nil nil file nil 'silent)))
    file))

(defun doom-packages--check-pin-form (package old)
  "Return the file setting PACKAGE's pin, or signal a `user-error' if OLD can't be rewritten there."
  (pcase-let ((`(,file ,beg ,end) (or (doom-packages--find-pin-form package)
                                      (user-error "cannot find where %s sets its :pin" package))))
    (with-temp-buffer
      (insert-file-contents file)
      (let ((case-fold-search t))
        (goto-char beg)
        (unless (search-forward (format "\"%s\"" old) end t)
          (user-error "the :pin of %s in %s is not a literal string" package file))))
    file))

(defun doom-packages--bump-plan (names)
  "Resolve upstream commits for the repos of NAMES (all installed if nil).
Returns (UPDATES TOTAL FAILED). UPDATES is a list of plists with :repo, :packages,
:old, :new, :files and :url; FAILED is an alist of (REPO . MESSAGE)."
  (let* ((installed (doom-packages--installed))
         (names (progn (dolist (name names)
                         (unless (memq name installed)
                           (user-error "%s is not an installed package" name)))
                       names))
         (repos (cl-remove-if-not
                 (lambda (repo) (or (null names)
                                    (cl-intersection names (plist-get (cdr repo) :packages))))
                 (doom-packages--repos)))
         (info (mapcar
                (lambda (repo)
                  (let* ((plist (cdr repo))
                         (recipes (mapcar (lambda (p) (doom-package-get p :recipe)) (plist-get plist :packages)))
                         (branch (cl-some (lambda (r) (plist-get r :branch)) recipes)))
                    (list (car repo) (plist-get plist :remote)
                          (if branch (format "refs/heads/%s" branch) "HEAD"))))
                repos))
         (resolved (doom-packages--ls-remote-all info))
         updates failed files)
    (dolist (repo repos)
      (pcase-let* ((plist (cdr repo))
                   (`(,sha . ,err) (cdr (assoc (car repo) resolved)))
                   (first (car (plist-get plist :packages)))
                   (recipe (doom-package-recipe first)))
        (cond ((null sha) (push (cons (car repo) err) failed))
              ((equal sha (plist-get plist :pin)))
              ((condition-case e
                   (progn (setq files (mapcar (lambda (p) (doom-packages--check-pin-form p (plist-get plist :pin)))
                                              (plist-get plist :packages)))
                          nil)
                 (user-error (push (cons (car repo) (cadr e)) failed) t)))
              (t
               (push (list :repo (car repo)
                           :packages (plist-get plist :packages)
                           :old (plist-get plist :pin) :new sha
                           :files (delete-dups files)
                           :url (format "https://%s/%s/compare/%s...%s"
                                        (if (eq (plist-get recipe :host) 'codeberg)
                                            "codeberg.org" "github.com")
                                        (plist-get recipe :repo) (plist-get plist :pin) sha))
                     updates)))))
    (list (nreverse updates) (length repos) (nreverse failed))))

;; Commits and pushes need the user's identity and credentials, so unlike
;; `doom-packages--git' this keeps the normal git config.
(defun doom-packages--user-git (dir &rest args)
  "Run git ARGS in DIR with the user's own git config. Returns (STATUS . OUTPUT)."
  (let ((default-directory (file-name-as-directory dir)))
    (with-temp-buffer
      (let ((status (apply #'call-process "git" nil t nil args)))
        (doom-log "packages:git: git %s -> %s" (string-join args " ") status)
        (cons status (string-trim-right (buffer-string)))))))

(defun doom-packages--toplevel (file)
  "The work tree root containing FILE, or nil if it is not in a git work tree."
  (let ((result (doom-packages--git (file-name-directory file) "rev-parse" "--show-toplevel")))
    (and (zerop (car result)) (file-name-as-directory (cdr result)))))

(defun doom-packages--own-checkout-p (dir)
  "Non-nil if DIR is the doom-lite checkout, the only repo bump and rollback push."
  (file-equal-p dir doom-emacs-dir))

(defun doom-packages--check-clean (files)
  "Signal a `user-error' unless every file of FILES is tracked and unmodified in git."
  (let ((bad (cl-remove-if
              (lambda (file)
                (when-let* ((top (doom-packages--toplevel file)))
                  (and (zerop (car (doom-packages--git top "ls-files" "--error-unmatch" "--" file)))
                       (zerop (car (doom-packages--git top "diff" "--quiet" "HEAD" "--" file))))))
              files)))
    (when bad
      (user-error "Not in git or has uncommitted changes: %s; commit or stash them first"
                  (mapconcat #'doom-packages--short-path bad ", ")))))

(defun doom-packages--commit-message (updates)
  "The commit message for UPDATES, which all touch the same repo."
  (let ((names (delete-dups (apply #'append (mapcar (lambda (up) (copy-sequence (plist-get up :packages))) updates)))))
    (concat (if (cdr names)
                (format "Bump %d packages" (length names))
              (format "Bump %s" (car names)))
            "\n\n"
            (mapconcat (lambda (up)
                         (format "- %s: %s -> %s"
                                 (mapconcat #'symbol-name (plist-get up :packages) ", ")
                                 (doom-packages--abbrev (plist-get up :old))
                                 (doom-packages--abbrev (plist-get up :new))))
                       updates "\n"))))

(defun doom-packages--commit-bump (updates)
  "Commit the pins UPDATES wrote, one commit per repo; push the doom-lite one.
Returns a list of (:dir :sha :pushed :files) plists, which is recorded for rollback."
  (let ((files (delete-dups (apply #'append (mapcar (lambda (up) (plist-get up :files)) updates))))
        groups commits)
    (dolist (file files)
      (let ((top (or (doom-packages--toplevel file) (user-error "%s is not in a git work tree" file))))
        (setf (alist-get top groups nil nil #'equal)
              (append (alist-get top groups nil nil #'equal) (list file)))))
    (pcase-dolist (`(,top . ,group) groups)
      (let* ((ups (cl-remove-if-not (lambda (up) (cl-intersection group (plist-get up :files) :test #'equal))
                                    updates))
             (result (apply #'doom-packages--user-git top "commit" "-m" (doom-packages--commit-message ups)
                            "--" group)))
        (unless (zerop (car result))
          (user-error "git commit failed in %s: %s" (abbreviate-file-name top) (cdr result)))
        (let ((sha (doom-packages--checkout-head top))
              (pushed nil))
          (when (doom-packages--own-checkout-p top)
            (let ((push (doom-packages--user-git top "push")))
              (if (zerop (car push))
                  (setq pushed t)
                (print! (warn "git push failed: %s; the commit is local, run git push in %s")
                        (cdr push) (abbreviate-file-name top)))))
          (push (list :dir top :sha sha :pushed pushed :files group) commits))))
    (nreverse commits)))

(defun doom-packages--describe-commits (commits)
  "A short summary such as \"abc1234 in ~/dir (pushed)\" for COMMITS."
  (mapconcat (lambda (c)
               (format "%s in %s (%s)" (doom-packages--abbrev (plist-get c :sha))
                       (abbreviate-file-name (plist-get c :dir))
                       (cond ((plist-get c :pushed) "pushed")
                             ((doom-packages--own-checkout-p (plist-get c :dir)) "push failed")
                             (t "not pushed"))))
             commits ", "))

(defun doom-packages--short-path (file)
  (if (file-in-directory-p file doom-emacs-dir)
      (file-relative-name file doom-emacs-dir)
    (abbreviate-file-name file)))

;;;###autoload
(defun doom-packages-bump (&optional names yes?)
  "Move the pins of NAMES (default: all installed packages) to upstream HEAD.
Shows what would change and asks first, unless YES? is non-nil.
Commits the pins it writes (and pushes doom-lite's). Returns non-nil if it wrote pins.
Does not sync."
  (doom-packages--require-git)
  (doom-initialize-packages)
  (pcase-let ((`(,updates ,total ,failed) (doom-packages--bump-plan names)))
    (pcase-dolist (`(,repo . ,msg) failed)
      (print! (warn "Could not resolve %s, skipping: %s") repo msg))
    (if (null updates)
        (print! (success "All pins are current"))
      (doom-packages--check-clean
       (delete-dups (apply #'append (mapcar (lambda (up) (plist-get up :files)) updates))))
      (dolist (up updates)
        (print! (item "%s: %s -> %s (%s)")
                (mapconcat #'symbol-name (plist-get up :packages) ", ")
                (doom-packages--abbrev (plist-get up :old))
                (doom-packages--abbrev (plist-get up :new))
                (mapconcat #'doom-packages--short-path (plist-get up :files) ", "))
        (print-group! (print! "%s" (plist-get up :url))))
      (print! "%d of %d repos have updates" (length updates) total)
      (when (or yes? (y-or-n-p (format! "  %s" "Bump them?")))
        (let ((files (delete-dups (apply #'append (mapcar (lambda (up) (plist-get up :files)) updates))))
              (originals nil))
          (dolist (file files)
            (push (cons file (doom-packages--file-bytes file)) originals))
          ;; Record even if a later rewrite fails: some files may already be written.
          (unwind-protect
              (dolist (up updates)
                (dolist (name (plist-get up :packages))
                  (doom-packages--rewrite-pin name (plist-get up :old) (plist-get up :new))))
            (doom-packages--record-bump updates originals))
          (doom-initialize-packages t)
          (dolist (up updates)
            (dolist (name (plist-get up :packages))
              (unless (equal (downcase (or (doom-package-get name :pin) "")) (plist-get up :new))
                (user-error "%s's :pin did not change to %s after rewriting; check its declaration"
                            name (plist-get up :new)))))
          (let ((commits (doom-packages--commit-bump updates)))
            (doom-packages--rollback-save
             (list :type 'bump :time (format-time-string "%FT%T%z")
                   :repos (doom-packages--record-repos updates)
                   :commits commits))
            (print! (success "Bumped %d repos, committed %s; syncing...")
                    (length updates) (doom-packages--describe-commits commits)))
          (print! "Restart Emacs and test. If something broke: doom rollback.")
          t)))))

;;; ** Rollback

(defconst doom-packages--rollback-header "Last change: doom %s at %s")

(defun doom-packages--rollback-file ()
  (expand-file-name "rollback.eld" doom-state-dir))

(defun doom-packages--file-bytes (file)
  "FILE's raw contents, base64-encoded so they survive printing byte for byte."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file)
    (base64-encode-string (buffer-string) t)))

(defun doom-packages--bytes-hash (b64)
  (secure-hash 'sha1 (base64-decode-string b64)))

(defun doom-packages--rollback-save (record)
  "Replace the undo record with RECORD (written to a temp file, then renamed)."
  (let ((file (doom-packages--rollback-file))
        (print-length nil) (print-level nil) (print-circle nil)
        (coding-system-for-write 'utf-8-unix))
    (make-directory (file-name-directory file) t)
    (let ((tmp (make-temp-file (concat file "."))))
      (with-temp-file tmp (prin1 record (current-buffer)))
      (rename-file tmp file t))))

(defun doom-packages--rollback-read ()
  "The undo record, or nil if there is none."
  (let ((file (doom-packages--rollback-file)))
    (when (file-exists-p file)
      (let ((coding-system-for-read 'utf-8-unix))
        (with-temp-buffer
          (insert-file-contents file)
          (read (current-buffer)))))))

(defun doom-packages--record-repos (updates)
  (mapcar (lambda (up)
            (list (plist-get up :repo)
                  :packages (plist-get up :packages)
                  :old (plist-get up :old) :new (plist-get up :new)))
          updates))

(defun doom-packages--record-bump (updates originals)
  "Save an undo record for UPDATES; ORIGINALS maps files to their pre-bump bytes."
  (let (files)
    (pcase-dolist (`(,file . ,before) originals)
      (let ((after (doom-packages--file-bytes file)))
        (unless (equal before after)
          (push (list file :before before :after-hash (doom-packages--bytes-hash after)) files))))
    (when files
      (doom-packages--rollback-save
       (list :type 'bump :time (format-time-string "%FT%T%z")
             :repos (doom-packages--record-repos updates)
             :files (nreverse files))))))

(defun doom-packages--checkout-head (dir)
  "The commit HEAD points at in the checkout DIR."
  (let ((result (doom-packages--git dir "rev-parse" "HEAD")))
    (unless (zerop (car result))
      (user-error "Cannot read HEAD of %s" (abbreviate-file-name dir)))
    (cdr result)))

;;;###autoload
(defun doom-packages-record-up (dir from to)
  "Save an undo record for a pull in DIR that moved HEAD from FROM to TO.
Does nothing if HEAD did not move, so an earlier record stays."
  (unless (equal from to)
    (doom-packages--rollback-save
     (list :type 'up :time (format-time-string "%FT%T%z") :dir dir :from from :to to))))

(defun doom-packages--rollback-preflight (record)
  "Signal a `user-error' unless RECORD can still be undone safely."
  (pcase (plist-get record :type)
    ((and 'bump (guard (plist-get record :commits)))
     (dolist (c (plist-get record :commits))
       (let ((dir (plist-get c :dir)))
         (unless (and (file-directory-p dir)
                      (zerop (car (doom-packages--git dir "merge-base" "--is-ancestor"
                                                      (plist-get c :sha) "HEAD"))))
           (user-error "Commit %s is no longer in %s's history"
                       (doom-packages--abbrev (plist-get c :sha)) (abbreviate-file-name dir)))
         (when-let* ((dirty (cl-remove-if
                             (lambda (f) (zerop (car (doom-packages--git dir "diff" "--quiet" "HEAD" "--" f))))
                             (plist-get c :files))))
           (user-error "%s has uncommitted changes; commit or stash them first"
                       (mapconcat #'doom-packages--short-path dirty ", "))))))
    ('bump
     (let ((edited (cl-remove-if
                    (lambda (entry)
                      (and (file-exists-p (car entry))
                           (equal (doom-packages--bytes-hash (doom-packages--file-bytes (car entry)))
                                  (plist-get (cdr entry) :after-hash))))
                    (plist-get record :files))))
       (when edited
         (user-error "%s changed since the bump; rolling back would overwrite those edits"
                     (mapconcat (lambda (e) (doom-packages--short-path (car e))) edited ", ")))))
    ('up
     (let ((dir (plist-get record :dir)))
       (unless (file-directory-p dir)
         (user-error "%s no longer exists" (abbreviate-file-name dir)))
       (let ((head (doom-packages--checkout-head dir)))
         (unless (equal head (plist-get record :to))
           (user-error "%s is at %s, not %s where doom up left it; roll back by hand"
                       (abbreviate-file-name dir)
                       (doom-packages--abbrev head) (doom-packages--abbrev (plist-get record :to)))))
       (unless (zerop (car (doom-packages--git dir "diff" "--quiet" "HEAD")))
         (user-error "Uncommitted changes in %s; commit or stash them first" (abbreviate-file-name dir)))))
    (type (user-error "Unknown rollback record type %S" type))))

(defun doom-packages--pins-in (text)
  "Alist of (PACKAGE . PIN) for the `package!' forms of TEXT that set a literal :pin."
  (let (pins)
    (with-temp-buffer
      (insert text)
      (with-syntax-table emacs-lisp-mode-syntax-table
        (goto-char (point-min))
        (while (search-forward "(package!" nil t)
          (let ((ppss (save-excursion (syntax-ppss))))
            (unless (or (nth 3 ppss) (nth 4 ppss))
              (goto-char (match-beginning 0))
              (let ((beg (point))
                    (form (condition-case nil (read (current-buffer))
                            (error (goto-char (1+ (point))) nil))))
                (when (consp form)
                  (let ((pin (plist-get (cddr form) :pin)))
                    (when (and (symbolp (cadr form)) (stringp pin))
                      (setf (alist-get (cadr form) pins) pin))))
                (ignore beg)))))))
    pins))

(defun doom-packages--pin-changes (dir from to)
  "Lines like \"NAME: OLD7 -> NEW7\" for pins that differ between FROM and TO in DIR."
  (let ((names (cdr (doom-packages--git dir "diff" "--name-only" from to "--" "*packages.el")))
        lines)
    (dolist (path (split-string names "\n" t))
      (let ((old (doom-packages--pins-in (cdr (doom-packages--git dir "show" (format "%s:%s" from path)))))
            (new (doom-packages--pins-in (cdr (doom-packages--git dir "show" (format "%s:%s" to path))))))
        (pcase-dolist (`(,name . ,pin) new)
          (let ((was (cdr (assq name old))))
            (unless (equal was pin)
              (push (format "%s: %s -> %s" name
                            (if was (doom-packages--abbrev was) "(none)")
                            (doom-packages--abbrev pin))
                    lines))))))
    (nreverse lines)))

(defun doom-packages--rollback-describe (record)
  "Print what undoing RECORD will do."
  (print! "%s" (format doom-packages--rollback-header
                       (if (eq (plist-get record :type) 'bump) "bump" "up")
                       (plist-get record :time)))
  (pcase (plist-get record :type)
    ('bump
     (pcase-dolist (`(,_repo . ,plist) (plist-get record :repos))
       (print! (item "%s: %s -> %s")
               (mapconcat #'symbol-name (plist-get plist :packages) ", ")
               (doom-packages--abbrev (plist-get plist :new))
               (doom-packages--abbrev (plist-get plist :old))))
     (if-let* ((commits (plist-get record :commits)))
         (progn
           (dolist (c commits)
             (print! "Reverts %s in %s (%s)" (doom-packages--abbrev (plist-get c :sha))
                     (abbreviate-file-name (plist-get c :dir))
                     (if (plist-get c :pushed) "pushed" "local")))
           (when (cl-some (lambda (c) (plist-get c :pushed)) commits)
             (print! "The revert of a pushed commit will be pushed too.")))
     (let ((files (mapcar #'car (plist-get record :files))))
       (print! "Files restored: %s" (mapconcat #'doom-packages--short-path files ", "))
       (when-let* ((outside (cl-remove-if (lambda (f) (file-in-directory-p f doom-emacs-dir)) files)))
         (print! (warn "%s is outside %s") (mapconcat #'doom-packages--short-path outside ", ")
                 (doom-packages--short-path doom-emacs-dir))))))
    ('up
     (let ((dir (plist-get record :dir))
           (from (plist-get record :from))
           (to (plist-get record :to)))
       (print! "doom-lite goes back from %s to %s" (doom-packages--abbrev to) (doom-packages--abbrev from))
       (print! "Commits undone:")
       (print-group!
         (dolist (line (split-string (cdr (doom-packages--git dir "log" "--oneline" (format "%s..%s" from to))) "\n" t))
           (print! "%s" line)))
       (when-let* ((pins (doom-packages--pin-changes dir from to)))
         (print! "Pin changes undone:")
         (print-group!
           (dolist (line pins) (print! "%s" line))))
       (print! "The next doom up pulls these commits again until they're reverted on master.")))))

(defun doom-packages--revert-commits (commits)
  "Revert each of COMMITS, or undo the reverts already made and signal a `user-error'."
  (let (done)
    (dolist (c commits)
      (let* ((dir (plist-get c :dir))
             (result (doom-packages--user-git dir "revert" "--no-edit" (plist-get c :sha))))
        (if (zerop (car result))
            (push dir done)
          (doom-packages--user-git dir "revert" "--abort")
          ;; --keep, not --hard: other uncommitted work in the repo must survive.
          (dolist (d done)
            (doom-packages--user-git d "reset" "--keep" "HEAD~1"))
          (user-error "git revert of %s failed in %s, nothing was changed: %s"
                      (doom-packages--abbrev (plist-get c :sha)) (abbreviate-file-name dir) (cdr result)))))))

(defun doom-packages--rollback-apply (record)
  (pcase (plist-get record :type)
    ((and 'bump (guard (plist-get record :commits)))
     (doom-packages--revert-commits (plist-get record :commits))
     (dolist (c (plist-get record :commits))
       (when (and (plist-get c :pushed) (doom-packages--own-checkout-p (plist-get c :dir)))
         (let ((push (doom-packages--user-git (plist-get c :dir) "push")))
           (unless (zerop (car push))
             (print! (warn "git push failed: %s; the revert is local, run git push in %s")
                     (cdr push) (abbreviate-file-name (plist-get c :dir))))))))
    ('bump
     (pcase-dolist (`(,file . ,plist) (plist-get record :files))
       (let ((coding-system-for-write 'no-conversion))
         (with-temp-buffer
           (set-buffer-multibyte nil)
           (insert (base64-decode-string (plist-get plist :before)))
           (write-region nil nil file nil 'silent)))))
    ('up
     (let ((result (doom-packages--git (plist-get record :dir) "reset" "--hard" (plist-get record :from))))
       (unless (zerop (car result))
         (user-error "git reset failed: %s" (cdr result)))))))

;;;###autoload
(defun doom-packages-rollback (&optional yes?)
  "Undo the last `doom bump' or `doom up' after showing it and asking, unless YES?.
Returns non-nil if it rolled back (the caller then syncs)."
  (doom-packages--require-git)
  (let ((record (doom-packages--rollback-read)))
    (if (null record)
        (progn (print! "Nothing to roll back") nil)
      (doom-packages--rollback-preflight record)
      (doom-packages--rollback-describe record)
      (when (or yes? (y-or-n-p (format! "  %s" "Roll back?")))
        (doom-packages--rollback-apply record)
        (delete-file (doom-packages--rollback-file))
        (print! (success "Rolled back; syncing..."))
        (when (and (eq (plist-get record :type) 'bump) (not (plist-get record :commits)))
          (print! "Pins restored; if you had committed the bump, the restored files now show as changes."))
        t))))

;;
;;; * Module DSL

;;;###autoload
(cl-defmacro package!
    (name &rest plist &key built-in recipe ignore _pin _disable)
  "Declares a package and how to install it (if applicable).

This macro is declarative and does not load nor install packages. It is used to
populate `doom-packages' with metadata about the packages Doom needs to keep
track of.

Only use this macro in a module's packages.el file.

Accepts the following properties:

 :recipe RECIPE
   Where the package comes from and which of its files to build. Every
   installed package needs one. A plist with these keys:
     :host    `github' (the default) or `codeberg'.
     :repo    \"owner/name\". Required.
     :files   Globs, relative to the repo root, that land in the build dir under
              their basename. `:defaults' stands for the default set and
              (:exclude GLOB...) removes files. A directory is linked file by
              file. Defaults to `doom-packages--default-files'.
     :compile nil to skip byte-compiling this package.
     :branch  Accepted but ignored; the pin decides.
   Any other key is an error at sync.
 :pin STR
   The full 40-character commit hash to check the package out at. Required for
   every installed package. Packages that share a repo must share a pin.
 :disable BOOL
   Do not install this package AND disable all of its `use-package!' and
   `after!' blocks.
 :ignore FORM
   Do not install this package.
 :built-in BOOL|'prefer
   Same as :ignore if the package is a built-in Emacs package. This is more to
   inform help commands like `doom/help-packages' that this is a built-in
   package. If set to \\='prefer, the package will not be installed if it is
   already provided by Emacs.

Returns t if package is successfully registered, and nil if it was disabled
elsewhere."
  (declare (indent defun))
  (when (and recipe (keywordp (car-safe recipe)))
    (cl-callf plist-put plist :recipe `(quote ,recipe)))
  ;; :built-in t is basically an alias for :ignore (locate-library NAME)
  (cl-remf plist :built-in)
  `(let* ((name ',name)
          (plist (cdr (assq name doom-packages)))
          (dir (dir!))
          (module (doom-module-from-path dir))
          (built-in? ,built-in))
     (unless (doom-context-p 'package)
       (signal 'doom-module-error
               (list module "package! can only be used in packages.el files")))
     (when (eq built-in? 'prefer)
       (setq built-in? (locate-library (symbol-name name) nil (get 'load-path 'initial-value))))
     (when built-in?
       (cl-callf plist-put plist :ignore t)
       (cl-callf plist-put plist :built-in t))
     ;; Record what module this declaration was found in
     (let ((module-list (plist-get plist :modules)))
       (unless (member module module-list)
         (cl-callf plist-put plist :modules
                   (append module-list
                           (list module)
                           (when (file-in-directory-p dir doom-user-dir)
                             '((:user . modules)))
                           nil))))
     (cl-callf plist-put plist :declared-in ,(macroexpand '(file!)))
     ;; Merge given plist with pre-existing one
     (cl-loop for (key value) on (list ,@plist) by 'cddr
              when (or (eq key :pin) value)
              do (cl-callf plist-put plist key value))
     ;; These are the only side-effects of this macro!
     (setf (alist-get name doom-packages) plist)
     (if (plist-get plist :disable)
         (add-to-list 'doom-disabled-packages name)
       (with-no-warnings
         (cons name plist)))))

(provide 'doom-packages)
;;; doom-packages.el ends here
