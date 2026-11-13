;;; lisp/lib/projects.el -*- lexical-binding: t; -*-

;;
;;; * Macros

;;;###autoload
(defmacro project-file-exists-p! (files &optional base-directory)
  "Checks if FILES exist at the current project's root.

The project's root is determined by `project-current', starting from BASE-DIRECTORY
(defaults to `default-directory'). FILES are paths relative to the project root,
unless they begin with a slash."
  `(file-exists-p! ,files (doom-project-root ,base-directory)))

(defun doom--project-completing-read (prompt collection &optional category)
  (completing-read
   prompt
   (if category
       (lambda (str pred action)
         (if (eq action 'metadata) ; used by embark/marginalia
             `(metadata (category . ,category))
           (complete-with-action action collection str pred)))
     collection)))

(defun doom--other-project-roots ()
  "Return known project roots, minus the current project's."
  (let ((current (doom-project-root)))
    (cl-remove-if (lambda (root)
                    (and current (file-equal-p (expand-file-name root) current)))
                  (project-known-project-roots))))


;;
;;; * Commands

;;;###autoload
(defun doom/find-file-in-other-project (project-root)
  "Performs `project-find-file' in a known project of your choosing."
  (interactive
   (list
    (doom--project-completing-read
     "Find file in project: " (doom--other-project-roots) 'project-file)))
  (unless (file-directory-p project-root)
    (error "Project directory '%s' doesn't exist" project-root))
  (doom-project-find-file project-root))

;;;###autoload
(defun doom/browse-in-other-project (project-root)
  "Performs `find-file' in a known project of your choosing."
  (interactive
   (list
    (doom--project-completing-read
     "Browse in project: " (doom--other-project-roots) 'project-file)))
  (unless (file-directory-p project-root)
    (error "Project directory '%s' doesn't exist" project-root))
  (doom-project-browse project-root))

;;;###autoload
(defun doom/browse-in-emacsd ()
  "Browse files from `doom-emacs-dir'."
  (interactive) (doom-project-browse doom-emacs-dir))

;;;###autoload
(defun doom/find-file-in-emacsd ()
  "Find a file under `doom-emacs-dir', recursively."
  (interactive) (doom-project-find-file doom-emacs-dir))

;;;###autoload
(defun doom/add-directory-as-project (dir)
  "Remember DIR as a project; plain directories get a .project file first.

Existing project roots are remembered as-is. Errors if DIR is inside another
project (which would mask it) or matches `project-list-exclude'."
  (interactive "D")
  (setq dir (file-name-as-directory (expand-file-name dir)))
  (let ((short-dir (abbreviate-file-name dir)))
    (when (doom--project-excluded-p dir)
      (user-error "ERROR: Directory is in project-list-exclude: %s" short-dir))
    (if-let* ((proj-dir (doom-project-root dir)))
        (if (file-equal-p proj-dir dir)
            (progn (project-remember-project (project-current nil dir))
                   (message "Remembered project: %s" short-dir))
          (user-error "ERROR: Directory is already inside another project: %s" proj-dir))
      (dolist (proj (project-known-project-roots))
        (when (file-in-directory-p proj dir)
          (user-error "ERROR: Directory contains a known project: %s" short-dir))
        (when (file-equal-p proj dir)
          (user-error "ERROR: Directory is already a known project: %s" short-dir)))
      (with-temp-file (expand-file-name ".project" dir))
      (message "Added directory as a project: %s" short-dir)
      ;; project.el caches negative lookups for a few seconds; drop that for the new marker.
      (project--clear-cache)
      (project-remember-project (project-current nil dir)))))


;;
;;; * Library

;;;###autoload
(defun doom-project-p (&optional dir)
  "Return t if DIR (defaults to `default-directory') is a valid project."
  (and (doom-project-root dir)
       t))

;;;###autoload
(defun doom-project-root (&optional dir)
  "Return the project root of DIR (defaults to `default-directory').
Returns nil if not in a project."
  (when-let* ((pr (project-current nil dir)))
    (expand-file-name (project-root pr))))

;;;###autoload
(defun doom-project-name (&optional dir)
  "Return the name of the current project.

Returns '-' if not in a valid project."
  (cond ((when-let* ((pr (project-current nil dir)))
           (project-name pr)))
        (dir (file-name-nondirectory (directory-file-name (expand-file-name dir))))
        ("-")))

;;;###autoload
(defun doom-project-expand (name &optional dir)
  "Expand NAME to project root."
  (expand-file-name name (doom-project-root dir)))

;;;###autoload
(defun doom-project-find-file (dir)
  "Jump to a file in DIR (searched recursively).

If DIR is not a project, it will be indexed (but not cached)."
  (unless (file-directory-p dir)
    (error "Directory %S does not exist" dir))
  (unless (file-readable-p dir)
    (error "Directory %S isn't readable" dir))
  (let* ((dir (file-truename dir))
         (default-directory dir)
         ;; Fall back to a transient project so only DIR's files are offered.
         (pr (or (project-current nil dir) (cons 'transient dir))))
    (condition-case _
        (project-find-file-in nil (list dir) pr)
      ;; FIX: project.el throws errors if DIR is an empty directory,
      ;;   which is poor UX.
      (wrong-type-argument
       (call-interactively #'find-file)))))

;;;###autoload
(defun doom-project-browse (dir)
  "Traverse a file structure starting linearly from DIR."
  (let ((default-directory (file-truename (expand-file-name dir))))
    (call-interactively #'find-file)))

;;;###autoload
(defun doom-project-ignored-p (project-root)
  "Return non-nil if temporary file or an installed package."
  (unless (file-remote-p project-root)
    (or (file-in-directory-p project-root temporary-file-directory)
        ;; Unbound outside a full Doom session (unit tests).
        (and (bound-and-true-p doom-local-dir)
             (file-in-directory-p project-root doom-local-dir)))))

(defun doom--project-excluded-p (dir)
  "Return non-nil if DIR would be dropped by `project-list-exclude'."
  (require 'project)  ; `project-list-exclude' is void until project.el loads
  (let ((pr (cons 'transient dir)))
    (cl-some (lambda (ex)
               (if (stringp ex)
                   (string-match-p ex (abbreviate-file-name dir))
                 (funcall ex pr)))
             project-list-exclude)))

(provide 'doom-lib '(projects))
;;; projects.el ends here
