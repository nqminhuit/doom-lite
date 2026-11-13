;;; ui/workspaces/autoload/evil.el -*- lexical-binding: t; -*-

;;;###autoload (autoload '+workspace:new "ui/workspaces/autoload/evil" nil t)
(evil-define-command +workspace:new (&optional name)
  "Ex wrapper around `+workspace/new'."
  (interactive "<a>") (+workspace/new name))

;;;###autoload (autoload '+workspace:rename "ui/workspaces/autoload/evil" nil t)
(evil-define-command +workspace:rename (new-name)
  "Ex wrapper around `+workspace/rename'."
  (interactive "<a>") (+workspace/rename new-name))

;;;###autoload (autoload '+workspace:delete "ui/workspaces/autoload/evil" nil t)
(evil-define-command +workspace:delete ()
  "Ex wrapper around `+workspace/kill'."
  (interactive) (+workspace/kill (+workspace-current-name)))

;;;###autoload (autoload '+workspace:switch-next "ui/workspaces/autoload/evil" nil t)
(evil-define-command +workspace:switch-next (&optional count)
  "Switch to next workspace. If COUNT, switch to the COUNT-th workspace (1-based)."
  (interactive "<c>")
  (if count (+workspace/switch-to (1- count)) (+workspace/cycle +1)))

;;;###autoload (autoload '+workspace:switch-previous "ui/workspaces/autoload/evil" nil t)
(evil-define-command +workspace:switch-previous (&optional count)
  "Switch to previous workspace. If COUNT, switch to the COUNT-th workspace (1-based)."
  (interactive "<c>")
  (if count (+workspace/switch-to (1- count)) (+workspace/cycle -1)))
