;;; config/default/autoload/files.el -*- lexical-binding: t; -*-

;;;###autoload
(defun +default/browse-project ()
  "Browse files from the current project's root."
  (interactive)
  (doom-project-browse (or (doom-project-root) default-directory)))
;; NOTE: No need for find-in-project, use `project-find-file'

;;;###autoload
(defun +default/browse-templates ()
  "Browse files from `+file-templates-dir'."
  (interactive) (doom-project-browse +file-templates-dir))
;;;###autoload
(defun +default/find-in-templates ()
  "Find a file under `+file-templates-dir', recursively."
  (interactive) (doom-project-find-file +file-templates-dir))

;;;###autoload
(defun +default/browse-notes ()
  "Browse files from `org-directory'."
  (interactive)
  (unless (bound-and-true-p org-directory)
    (require 'org))
  (doom-project-browse org-directory))
;;;###autoload
(defun +default/find-in-notes ()
  "Find a file under `org-directory', recursively."
  (interactive)
  (unless (bound-and-true-p org-directory)
    (require 'org))
  (doom-project-find-file org-directory))

;;;###autoload
(defun +default/find-file-under-here ()
  "Perform a recursive file search from the current directory."
  (interactive)
  (doom-project-find-file default-directory))

;;;###autoload
(defun +default/discover-projects (dir)
  "Remember every project found (recursively) under DIR."
  (interactive "DDiscover projects under: ")
  (project-remember-projects-under dir t))

;;;###autoload
(defun +default/dired (arg)
  "Open a directory in dired.
If prefix ARG is non-nil, prompt for a known project to open in dired."
  (interactive "P")
  (apply #'dired
         (if arg
             (list (completing-read "Open dired in project: " (project-known-project-roots)))
           (dired-read-dir-and-switches ""))))
