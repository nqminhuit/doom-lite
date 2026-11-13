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

(defun doom-packages--git (dir &rest args)
  "Run git ARGS in DIR with user and system git config ignored.
Returns (STATUS . OUTPUT)."
  (let ((default-directory (file-name-as-directory dir)))
    (with-environment-variables
        (("GIT_CONFIG" nil)
         ("GIT_CONFIG_NOSYSTEM" "1")
         ("GIT_CONFIG_GLOBAL" (or (getenv "DOOMGITCONFIG") "/dev/null"))
         ("GIT_TERMINAL_PROMPT" "0"))
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
