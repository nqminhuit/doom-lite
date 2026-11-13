;;; ui/workspaces/autoload/workspaces.el -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'tab-bar)
(require 'project)

(defvar +workspaces-main)
(defvar +workspaces-switch-project-function)

(defvar +workspaces--project-roots nil
  "Alist mapping a workspace name to the project root it was opened for.")

;;;###autoload
(defface +workspace-tab-selected-face '((t (:inherit highlight)))
  "The face for the selected tab displayed by `+workspace/display'."
  :group 'tab-bar)

;;;###autoload
(defface +workspace-tab-face '((t (:inherit default)))
  "The face for unselected tabs displayed by `+workspace/display'."
  :group 'tab-bar)


;;
;;; Library

;;;###autoload
(defun +workspace-list-names ()
  "Return the names of the current frame's workspaces, in order."
  (mapcar (lambda (tab) (alist-get 'name tab)) (funcall tab-bar-tabs-function)))

;;;###autoload
(defun +workspace-current-name ()
  "Get the name of the current workspace."
  (alist-get 'name (tab-bar--current-tab)))

;;;###autoload
(defun +workspace-exists-p (name)
  "Return non-nil if NAME is the name of an existing workspace."
  (member name (+workspace-list-names)))

(defun +workspace--rename-tab (name)
  "Rename the current tab to NAME, silencing tab-bar's \"Renamed tab\" message."
  (let ((inhibit-message t)
        (message-log-max nil))
    (tab-bar-rename-tab name)))

(defun +workspace--generate-name ()
  "Return the first `#N' (N >= 1) that is not a workspace name."
  (let ((names (+workspace-list-names)) (n 1))
    (while (member (format "#%d" n) names) (cl-incf n))
    (format "#%d" n)))

(defun +workspace--select (index)
  "Select the workspace at 0-based INDEX."
  (tab-bar-select-tab (1+ index)))


;;
;;; Echo area display

(defun +workspace--tabline ()
  (let ((current (+workspace-current-name)))
    (mapconcat
     #'identity
     (cl-loop for name in (+workspace-list-names)
              for i from 1
              collect (propertize (format " [%d] %s " i name)
                                  'face (if (equal current name)
                                            '+workspace-tab-selected-face
                                          '+workspace-tab-face)))
     " ")))

(defun +workspace--message-body (message &optional type)
  (concat (+workspace--tabline)
          (propertize " | " 'face 'font-lock-comment-face)
          (propertize (format "%s" message)
                      'face (pcase type
                              ('error 'error)
                              ('warn 'warning)
                              ('success 'success)
                              ('info 'font-lock-comment-face)))))

;;;###autoload
(defun +workspace-message (message &optional type)
  "Show MESSAGE in the echo area next to a listing of workspaces."
  (message "%s" (+workspace--message-body message type)))

;;;###autoload
(defun +workspace-error (message &optional noerror)
  "Show MESSAGE as an error next to the workspaces; only message if NOERROR."
  (funcall (if noerror #'message #'error)
           "%s" (+workspace--message-body message 'error)))

;;;###autoload
(defun +workspace/display ()
  "Display a list of workspaces (like tabs) in the echo area."
  (interactive)
  (dlet ((message-log-max nil))
    (message "%s" (+workspace--tabline))))


;;
;;; Commands

;;;###autoload
(defun +workspace/new (&optional name)
  "Create a workspace showing the fallback buffer, named NAME or `#N'."
  (interactive)
  (if (and name (+workspace-exists-p name))
      (+workspace-error (format "A workspace named '%s' already exists" name) t)
    (tab-bar-new-tab)
    (delete-other-windows)
    (switch-to-buffer (doom-fallback-buffer))
    (+workspace--rename-tab (or name (+workspace--generate-name)))
    (+workspace/display)))

;;;###autoload
(defun +workspace/new-named (name)
  "Create a new workspace named NAME."
  (interactive "sWorkspace Name: ")
  (+workspace/new name))

;;;###autoload
(defun +workspace/rename (new-name)
  "Rename the current workspace to NEW-NAME."
  (interactive (list (read-string "New workspace name: " (+workspace-current-name))))
  (let ((old (+workspace-current-name)))
    (+workspace--rename-tab new-name)
    (+workspace-message (format "Renamed '%s'->'%s'" old new-name) 'success)))

;;;###autoload
(defun +workspace/kill (&optional name)
  "Kill workspace NAME (default: the current one; with a prefix arg, prompt)."
  (interactive
   (list (and current-prefix-arg
              (completing-read "Kill workspace: " (+workspace-list-names) nil t))))
  (let ((name (or name (+workspace-current-name))))
    (cond ((not (+workspace-exists-p name))
           (+workspace-message (format "'%s' workspace doesn't exist" name) 'warn))
          ((null (cdr (+workspace-list-names)))
           (+workspace-error "Can't kill the last workspace" t))
          (t
           (tab-bar-close-tab-by-name name)
           (setq +workspaces--project-roots
                 (assoc-delete-all name +workspaces--project-roots))
           (+workspace-message (format "Deleted '%s' workspace" name) 'success)))))

;;;###autoload
(defun +workspace/switch-to (index)
  "Switch to the workspace at INDEX (0-based number) or named INDEX (string)."
  (interactive
   (list (if current-prefix-arg
             (prefix-numeric-value current-prefix-arg)
           (completing-read "Switch to workspace: " (+workspace-list-names) nil t))))
  (when (and (stringp index) (string-match-p "\\`[0-9]+\\'" index))
    (setq index (string-to-number index)))
  (let ((names (+workspace-list-names)))
    (cond ((numberp index)
           (if (and (>= index 0) (< index (length names)))
               (progn (+workspace--select index) (+workspace/display))
             (+workspace-error (format "No workspace at #%d" index) t)))
          ((member index names)
           (+workspace--select (cl-position index names :test #'equal))
           (+workspace/display))
          (t (+workspace-error (format "No workspace named '%s'" index) t)))))

;;;###autoload
(dotimes (i 9)
  (defalias (intern (format "+workspace/switch-to-%d" i))
    (lambda () (interactive) (+workspace/switch-to i))
    (format "Switch to workspace #%d" (1+ i))))

;;;###autoload
(defun +workspace/switch-to-final ()
  "Switch to the last workspace."
  (interactive)
  (+workspace/switch-to (1- (length (+workspace-list-names)))))

;;;###autoload
(defun +workspace/other ()
  "Switch to the previously selected workspace."
  (interactive)
  (if (cdr (+workspace-list-names))
      (progn (tab-bar-switch-to-recent-tab) (+workspace/display))
    (+workspace-error "No other workspaces" t)))

;;;###autoload
(defun +workspace/cycle (n)
  "Cycle N workspaces to the right (left if negative), wrapping around."
  (interactive "p")
  (let* ((names (+workspace-list-names))
         (len (length names)))
    (if (< len 2)
        (+workspace-error "No other workspaces" t)
      (+workspace--select
       (mod (+ (cl-position (+workspace-current-name) names :test #'equal) n) len))
      (+workspace/display))))

;;;###autoload
(defun +workspace/switch-left (&optional n)
  "Switch N workspaces to the left."
  (interactive "p")
  (+workspace/cycle (- (or n 1))))

;;;###autoload
(defun +workspace/switch-right (&optional n)
  "Switch N workspaces to the right."
  (interactive "p")
  (+workspace/cycle (or n 1)))


;;
;;; Projects

(defun +workspaces--unique-name (name root)
  "Return NAME, or `parent/NAME' (more parents as needed) if NAME is taken by another root."
  (let ((candidate name)
        (parts (butlast (split-string (directory-file-name root) "/" t)))
        (taken (lambda (n)
                 (when-let* ((known (assoc n +workspaces--project-roots)))
                   (and (+workspace-exists-p n) (not (equal (cdr known) root)))))))
    (while (and (funcall taken candidate) parts)
      (setq candidate (concat (car (last parts)) "/" candidate)
            parts (butlast parts)))
    candidate))

(defun +workspaces--recyclable-p ()
  "Non-nil if the current workspace is the untouched main one."
  (and (equal (+workspace-current-name) +workspaces-main)
       (not (cl-some (lambda (w) (doom-real-buffer-p (window-buffer w)))
                     (window-list)))))

;;;###autoload
(defun +workspaces-switch-to-project-h (&optional dir)
  "Switch to (or create) the workspace for the project at DIR."
  (let* ((root (file-name-as-directory (file-truename (or dir default-directory))))
         (name (+workspaces--unique-name
                (let ((default-directory root)) (doom-project-name))
                root)))
    (cond ((+workspace-exists-p name)
           (+workspace--select (cl-position name (+workspace-list-names) :test #'equal)))
          ((+workspaces--recyclable-p)
           (+workspace--rename-tab name))
          (t (+workspace/new name)))
    (setf (alist-get name +workspaces--project-roots nil nil #'equal) root)
    (with-current-buffer (doom-fallback-buffer)
      (setq default-directory root))
    (unless current-prefix-arg
      (funcall +workspaces-switch-project-function root))
    (+workspace-message (format "Switched to '%s'" name) 'success)))

;;;###autoload
(defun +workspaces/switch-to-project ()
  "Switch to a project's workspace; installed as `project-switch-commands'."
  (interactive)
  (+workspaces-switch-to-project-h
   (expand-file-name (project-root (project-current t)))))


;;
;;; Hooks

;;;###autoload
(defun +workspaces-init-frame-h (&optional frame)
  "Name the first tab of FRAME `+workspaces-main' unless it was named already."
  (with-selected-frame (or frame (selected-frame))
    (let ((tab (tab-bar--current-tab)))
      (unless (alist-get 'explicit-name tab)
        (+workspace--rename-tab +workspaces-main)))))
