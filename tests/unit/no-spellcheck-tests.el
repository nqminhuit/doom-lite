;;; no-spellcheck-tests.el --- spellcheck stays removed -*- lexical-binding: t; -*-

(require 'ert)

(defconst no-spellcheck-test--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "tests/config-dir.el" no-spellcheck-test--root) nil t)

(defun no-spellcheck-test--setting-form ()
  "The top-level `setq' of `text-mode-ispell-word-completion' in core."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "lisp/doom-emacs.el" no-spellcheck-test--root))
    (goto-char (point-min))
    (let (form)
      (condition-case nil
          (while (not form)
            (let ((f (read (current-buffer))))
              (when (and (eq (car-safe f) 'setq)
                         (eq (nth 1 f) 'text-mode-ispell-word-completion))
                (setq form f))))
        (end-of-file nil))
      form)))

(ert-deftest no-spellcheck/core-disables-ispell-capf ()
  (let ((form (no-spellcheck-test--setting-form)))
    (should form)
    (should (null (nth 2 form)))
    (let ((text-mode-ispell-word-completion t))
      (eval form t)
      (with-temp-buffer
        (text-mode)
        (should-not (memq #'ispell-completion-at-point completion-at-point-functions))
        (should-not (memq #'ispell-completion-at-point
                          (default-value 'completion-at-point-functions)))))))

(ert-deftest no-spellcheck/no-leftovers ()
  (let (hits)
    (dolist (d (list (tcd-config-dir) "modules" "lisp"))
      (dolist (f (directory-files-recursively
                  (expand-file-name d no-spellcheck-test--root) "\\.el\\'"))
        (with-temp-buffer
          (insert-file-contents f)
          (goto-char (point-min))
          (while (re-search-forward "jinx\\|flyspell\\|spell-fu" nil t)
            (push (file-relative-name f no-spellcheck-test--root) hits)))))
    (should-not hits)))
