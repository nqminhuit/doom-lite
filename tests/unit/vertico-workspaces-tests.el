;;; vertico-workspaces-tests.el --- +vertico/switch-workspace-buffer dispatch -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'project)

(defconst vwt--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defmacro modulep! (&rest _) t)
(load (expand-file-name "modules/completion/vertico/autoload/workspaces.el" vwt--root) nil t)

(defun vwt--dispatch (dir)
  "Return the command `+vertico/switch-workspace-buffer' calls from DIR."
  (let ((default-directory (file-name-as-directory dir))
        (project-list-file (make-temp-file "vwt-projects"))
        called)
    (cl-letf (((symbol-function 'project-switch-to-buffer) (lambda () (interactive) (setq called 'project)))
              ((symbol-function 'consult-buffer) (lambda () (interactive) (setq called 'consult))))
      (+vertico/switch-workspace-buffer))
    called))

(ert-deftest vwt-project-uses-project-buffers ()
  (unless (executable-find "git") (ert-skip "git missing"))
  (let ((dir (file-name-as-directory (file-truename (make-temp-file "vwt-proj" t)))))
    (let ((default-directory dir)) (call-process "git" nil nil nil "init" "-q"))
    (should (eq 'project (vwt--dispatch dir)))))

(ert-deftest vwt-outside-project-uses-consult-buffer ()
  (let ((dir (file-name-as-directory (file-truename (make-temp-file "vwt-plain" t)))))
    (should (eq 'consult (vwt--dispatch dir)))))
