;;; completion/vertico/autoload/workspaces.el -*- lexical-binding: t; -*-
;;;###if (modulep! :ui workspaces)

;;;###autoload
(defun +vertico/switch-workspace-buffer ()
  "Switch to a project buffer inside a project, any buffer otherwise."
  (interactive)
  (if (project-current)
      (call-interactively #'project-switch-to-buffer)
    (call-interactively #'consult-buffer)))

;;;###autoload
(defun +vertico/embark-open-in-new-workspace (file)
  "Open file in a new workspace."
  (interactive "GFile:")
  (+workspace/new)
  (find-file file))

;;; workspaces.el ends here
