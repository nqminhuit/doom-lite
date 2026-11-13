;;; modulep-targets-tests.el --- modulep! only names vendored modules -*- lexical-binding: t; -*-

;; Guards against dead branches for modules that were deleted from the fork
;; (e.g. `(modulep! :completion ivy)') coming back with a merge or copy-paste.

(require 'ert)
(require 'cl-lib)

(defconst modulep-test--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defconst modulep-test--form-re
  "(\\(?:modulep!\\|doom-module-active-p\\) +\\(:[a-z]+\\) +'?\\([a-z][a-z0-9-]*\\)"
  "Matches the `:CATEGORY MODULE' of a literal modulep! form.")

(defun modulep-test--files ()
  "Every .el file under modules/ and lisp/."
  (cl-loop for d in '("modules" "lisp")
           append (directory-files-recursively
                   (expand-file-name d modulep-test--root) "\\.el\\'")))

(defun modulep-test--targets ()
  "Alist of (CATEGORY . MODULE) -> files that reference it."
  (let (acc)
    (dolist (f (modulep-test--files))
      (with-temp-buffer
        (insert-file-contents f)
        (while (re-search-forward modulep-test--form-re nil t)
          (let* ((key (cons (substring (match-string 1) 1) (match-string 2)))
                 (cell (assoc key acc)))
            (if cell
                (cl-pushnew f (cdr cell) :test #'equal)
              (push (list key f) acc))))))
    acc))

(ert-deftest modulep-targets/scan-finds-forms ()
  (should (assoc '("tools" . "lsp") (modulep-test--targets))))

(ert-deftest modulep-targets/every-target-is-vendored ()
  (let (missing)
    (dolist (entry (modulep-test--targets))
      (let* ((cat (car (car entry)))
             (mod (cdr (car entry)))
             (dir (expand-file-name
                   (if (equal cat "minh")
                       (format "config/modules/minh/%s/" mod)
                     (format "modules/%s/%s/" cat mod))
                   modulep-test--root)))
        ;; `:user' is the special DOOMDIR module and has no directory.
        (unless (or (equal cat "user") (file-directory-p dir))
          (push (format ":%s %s (in %s)" cat mod
                        (mapconcat (lambda (f) (file-relative-name f modulep-test--root))
                                   (cdr entry) ", "))
                missing))))
    (should-not (progn (when missing
                         (message "modulep! targets without a module dir:\n%s"
                                  (string-join (sort missing #'string<) "\n")))
                       missing))))

;;; modulep-targets-tests.el ends here
