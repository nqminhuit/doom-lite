;;; autodef-tests.el --- every set-*! call has a definition -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst autodef-test--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "tests/config-dir.el" autodef-test--root) nil t)

(defun autodef-test--files (&rest dirs)
  "All .el files under DIRS (relative to the repo root, or absolute)."
  (cl-loop for d in dirs
           append (directory-files-recursively
                   (expand-file-name d autodef-test--root) "\\.el\\'")))

(defun autodef-test--read (file)
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(defun autodef-test--called-names ()
  "Names of every `(set-NAME!' call in the repo's modules/ and the config dir."
  (let (names)
    (dolist (f (autodef-test--files "modules" (tcd-config-dir)))
      (with-temp-buffer
        (insert-file-contents f)
        (goto-char (point-min))
        (while (re-search-forward "(\\(set-[a-z-]+!\\)[ )\n]" nil t)
          (push (match-string 1) names))))
    (delete-dups names)))

(ert-deftest autodef/set-star-calls-are-defined ()
  (let* ((corpus (mapconcat #'autodef-test--read
                            (autodef-test--files "modules" "lisp") "\n"))
         (undefined
          (cl-remove-if
           (lambda (name)
             (string-match-p
              (format "^[ \t]*(\\(cl-\\)?def\\(un\\|macro\\|alias\\)\\*? '?%s[ )\n]"
                      (regexp-quote name))
              corpus))
           (autodef-test--called-names))))
    (should-not (progn (when undefined
                         (message "Undefined set-*! functions: %s"
                                  (string-join (sort undefined #'string<) ", ")))
                       undefined))))

;;; autodef-tests.el ends here
