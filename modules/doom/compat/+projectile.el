;;; modules/doom/compat/+projectile.el -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(defvar doom-project-cache-dir (file-name-concat doom-profile-cache-dir "projectile/")
  "The directory where per-project projectile file index caches are stored.

Must end with a slash.")


;;
;;; Packages

(use-package! projectile
  :commands (projectile-project-root
             projectile-project-name
             projectile-project-p
             projectile-locate-dominating-file
             projectile-relevant-known-projects)
  :init
  (setq projectile-enable-caching (if noninteractive t 'persistent)
        projectile-globally-ignored-files '(".DS_Store" "TAGS")
        projectile-globally-ignored-file-suffixes '(".elc" ".pyc" ".o")
        projectile-kill-buffers-filter 'kill-only-files
        projectile-ignored-projects '("~/")
        projectile-known-projects-file (file-name-concat doom-project-cache-dir "projects.eld")
        projectile-ignored-project-function #'doom-project-ignored-p
        projectile-fd-executable doom-fd-executable)

  (global-set-key [remap evil-jump-to-tag] #'projectile-find-tag)
  (global-set-key [remap find-tag]         #'projectile-find-tag)

  :config
  (make-directory doom-project-cache-dir t)

  ;; Projectile runs four functions to determine the root (in this order):
  ;;
  ;; + `projectile-root-local' -> checks the `projectile-project-root' variable
  ;;    for an explicit path.
  ;; + `projectile-root-bottom-up' -> searches from / to your current directory
  ;;   for the paths listed in `projectile-project-root-files-bottom-up'. This
  ;;   includes .git and .project
  ;; + `projectile-root-top-down' -> searches from the current directory down to
  ;;   / the paths listed in `projectile-root-files', like package.json,
  ;;   setup.py, or Cargo.toml
  ;; + `projectile-root-top-down-recurring' -> searches from the current
  ;;   directory down to / for a directory that has one of
  ;;   `projectile-project-root-files-top-down-recurring' but doesn't have a
  ;;   parent directory with the same file.
  ;;
  ;; In the interest of performance, we reduce the number of project root marker
  ;; files/directories projectile searches for when resolving the project root.
  ;;
  ;; These will be filled by other modules. We build this list manually so
  ;; projectile doesn't perform so many file checks every time it resolves a
  ;; project's root -- particularly when a file has no project.
  (setq projectile-project-root-files '()
        projectile-project-root-files-top-down-recurring '("Makefile"))

  ;; Adds a more editor/plugin-agnostic project marker.
  (add-to-list 'projectile-project-root-files-bottom-up ".project")

  (push (abbreviate-file-name doom-local-dir) projectile-globally-ignored-directories)

  ;; Per-project compilation buffers
  (setq compilation-buffer-name-function #'projectile-compilation-buffer-name
        compilation-save-buffers-predicate #'projectile-current-project-buffer-p)

  (define-advice projectile-project-cache-file
      (:around (fn &optional proot) centralize-cache-file)
    "Write per-project cache files to a centralized location.
This is to prevent littering projects with additional dotfiles."
    (let* ((proot (or proot (doom-project-root) default-directory))
           (projectile-cache-file
            (expand-file-name
             (format "%s-%s" (doom-project-name proot) (sha1 proot))
             doom-project-cache-dir)))
      (funcall fn proot)))

  ;; REVIEW: PR this upstream
  (define-advice projectile-ensure-project (:before (dir) update-known-projects)
    "To ensure `projectile-known-projects' is populated before it is used.

`projectile-ensure-project' may be called before projectile has loaded its list
of known projects, causing some project-listing/switching commands to report no
known projects."
    (unless dir
      (when (and (eq projectile-require-project-root 'prompt)
                 (not projectile-known-projects))
        (projectile-known-projects))
      (advice-remove 'projectile-ensure-project #'doom--projectile-update-known-projects-a)))

  (define-advice projectile-dirconfig-file (:override () support-dotproject-file)
    "Support a more generic .project file as an alternative to .projectile."
    (let ((proot (projectile-project-root)))
      (cond ((file-exists-p! (or projectile-dirconfig-file ".project") proot))
            ((expand-file-name ".project" proot)))))

  ;; REVIEW: PR this upstream
  (define-advice projectile-files-to-ensure (:override (&rest _) fix-in-non-projects)
    "Fix type error if executed in a non-project context.

`projectile-files-to-ensure' binds `default-directory' to the result of
`projectile-project-root', which returns nil when called from a buffer outside
of a project, poisoning the entire downstream call chain with a
wrong-type-argument error."
    (let ((default-directory (or (projectile-project-root) default-directory)))
      (flatten-tree (mapcar #'file-expand-wildcards
                            (projectile-patterns-to-ensure)))))

  ;; Disable commands that won't work, as is, and that Doom already provides a
  ;; better alternative for.
  (put 'projectile-ag 'disabled "Use +default/search-project instead")
  (put 'projectile-ripgrep 'disabled "Use +default/search-project instead")
  (put 'projectile-grep 'disabled "Use +default/search-project instead")

  ;; HACK: Some MSYS utilities auto expanded the `/' path separator, so we need
  ;;   to prevent it.
  (when doom--system-windows-p
    (setenv "MSYS_NO_PATHCONV" "1") ; Fix path in Git Bash
    (setenv "MSYS2_ARG_CONV_EXCL" "--path-separator")) ; Fix path in MSYS2

  (define-advice projectile-get-ext-command (:around (fn vcs &optional directory) use-generic-command)
    "Only use `projectile-generic-command' for indexing project files.

And if it's a function, evaluate it. Ensures that we don't rely on VCS-specific
commands to generate our file lists. That's 7 commands to maintain, versus the
more generic, consistent, reliable, and performant `fd' or `ripgrep'."
    (let ((default-directory (or directory default-directory)))
      (if (and (functionp projectile-generic-command)
               (not (file-remote-p default-directory)))
          (funcall projectile-generic-command vcs)
        (let ((projectile-git-submodule-command
               (or projectile-git-submodule-command
                   (get 'projectile-git-submodule-command 'initial-value))))
          (funcall fn vcs)))))

  ;; HACK: `projectile-generic-command' doesn't typically support a function,
  ;;   but my `doom--only-use-generic-command-a' advice allows this. I do it
  ;;   this way to make it easier for folks to undo the change (if not set to a
  ;;   function, projectile will revert to default behavior).
  (put 'projectile-git-submodule-command 'initial-value projectile-git-submodule-command)
  (setq projectile-git-submodule-command nil
        ;; Include (but don't follow) symlinks in file listings.
        projectile-git-fd-args (concat "-tl " projectile-git-fd-args)
        projectile-indexing-method 'hybrid
        projectile-generic-command
        (lambda (_)
          ;; If fd or ripgrep exists, use it to produce file listings for
          ;; projectile commands. fd is a rust program that is significantly
          ;; faster than git ls-files, find, or the various VCS commands
          ;; projectile is configured to use. Plus, it respects .gitignore.
          (cond
           ((when-let*
                ((doom-fd-executable)
                 (projectile-git-use-fd)
                 ;; REVIEW: Temporary fix for #6618. Improve me later.
                 (version (with-memoization (get 'doom-fd-executable 'version)
                            (cadr (split-string (cdr (doom-call-process doom-fd-executable "--version"))
                                                " " t))))
                 ((ignore-errors (version-to-list version))))
              (string-join
               (delq
                nil (list doom-fd-executable "."
                          (if (version< version "8.3.0")
                              (replace-regexp-in-string "--strip-cwd-prefix" "" projectile-git-fd-args t t)
                            projectile-git-fd-args)
                          (when project-vc-backend-markers-alist
                            (mapconcat (fn! (format "-E %s" (shell-quote-argument (cdr %))))
                                       project-vc-backend-markers-alist
                                       " "))
                          (if doom--system-windows-p " --path-separator=/" "")))
               " ")))
           ;; Otherwise, resort to ripgrep, which is also faster than find
           (doom-ripgrep-executable
            (string-join
             (delq
              nil (list doom-ripgrep-executable
                        "-0 --files --follow --color=never --hidden"
                        (when project-vc-backend-markers-alist
                          (mapconcat (fn! (format "-g!%s" (shell-quote-argument (cdr %))))
                                     project-vc-backend-markers-alist
                                     " "))
                        (if doom--system-windows-p " --path-separator=/")))
             " "))
           ((not doom--system-windows-p) "find . -type f | cut -c3- | tr '\\n' '\\0'")
           ("find . -type f -print0"))))

  (define-advice projectile-default-generic-command
      (:around (fn &rest args) suppress-error)
    "Suppress error so compile/test/run/configure commands fail gracefully.

If projectile can't tell what kind of project you're in, it issues an error when
using many of projectile's command, e.g. `projectile-compile-command',
`projectile-run-project', `projectile-test-project', and
`projectile-configure-project', for instance. This makes them gracefully prompt
you, instead."
    (ignore-errors (apply fn args)))

  (projectile-mode +1))

;;; +projectile.el ends here
