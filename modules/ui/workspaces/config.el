;;; ui/workspaces/config.el -*- lexical-binding: t; -*-

;; Workspaces are built-in `tab-bar' tabs. The bar itself stays hidden (we never
;; enable `tab-bar-mode'); `+workspace/display' shows the tabs in the echo area.

(defvar +workspaces-main "main"
  "The name given to the first workspace of a frame.")

(defvar +workspaces-switch-project-function #'doom-project-find-file
  "The function to run after switching to a project workspace.
It takes one argument: the project root.")

(setq tab-bar-show nil
      tab-bar-new-tab-to 'rightmost)

(add-hook 'doom-init-ui-hook #'+workspaces-init-frame-h)
(add-hook 'after-make-frame-functions #'+workspaces-init-frame-h)

(with-eval-after-load 'project
  (setq project-switch-commands #'+workspaces/switch-to-project))
