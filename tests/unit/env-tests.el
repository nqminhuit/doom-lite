;;; env-tests.el --- `doom-env-deny' defaults -*- lexical-binding: t; -*-

(require 'ert)

(defconst envt-deny
  (with-temp-buffer
    (insert-file-contents (expand-file-name "../../bin/doom-env" (file-name-directory (or load-file-name buffer-file-name))))
    (re-search-forward "^(defcustom doom-env-deny")
    (goto-char (match-beginning 0))
    (eval (nth 2 (read (current-buffer))) t)))

(defun envt--denied-p (name)
  (cl-some (lambda (re) (string-match-p re name)) envt-deny))

(ert-deftest envt-denies-claude-session-vars ()
  (dolist (name '("CLAUDECODE" "CLAUDE_CODE_MESSAGING_TOKEN" "CLAUDE_PID" "CLAUDE_EFFORT"))
    (should (envt--denied-p name))))

(ert-deftest envt-keeps-user-vars ()
  (dolist (name '("PATH" "CLAUDE_CONFIG_DIR"))
    (should-not (envt--denied-p name))))
