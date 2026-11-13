;;; core-trims-tests.el --- files and symbols removed by the P10 core trims -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst core-trims-test--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "tests/config-dir.el" core-trims-test--root) nil t)

(defconst core-trims-test--deleted
  '("lisp/lib/sandbox.el" "lisp/lib/store.el" "lisp/lib/plist.el"
    "modules/doom/cli" "bin/org-capture" "bin/doom.ps1" "bin/doom.sh" "profiles"))

(defconst core-trims-test--compat-symbols
  '("MODULES" "NATIVECOMP" "doom-private-dir" "doom-etc-dir" "dynamic-modules"
    "jansson" "harfbuzz" "doom-dir" "doom-plist-get" "doom-unicode-font"
    "featurep!" "doom-enlist" "letenv!" "eval-if!" "eval-when!" "setq!"
    "doom-load-envvars-file" "doom-compile-functions" "appendq!" "delq!"
    "pushnew!" "prependq!")
  "Removed compat names; matched only in code positions, not prose or comments.")

(defconst core-trims-test--code-re
  (concat "\\(?:[('#]\\|def[a-z]+ \\)" (regexp-opt core-trims-test--compat-symbols t) "\\_>"))

(defconst core-trims-test--plain-re "doom/sandbox\\|\\_<doom-store-\\|\\_<doom-plist-")

(defconst core-trims-test--allowed '(("bin/doom-doctor" . "doom-dir"))
  "Files that legitimately use a removed name as a local variable.")

(defun core-trims-test--files ()
  (cl-loop for d in (list "lisp" "modules" (tcd-config-dir) "bin")
           append (directory-files-recursively
                   (expand-file-name d core-trims-test--root)
                   (if (equal d "bin") "\\`[^.]" "\\.el\\'"))))

(ert-deftest core-trims/deleted-files-are-gone ()
  (dolist (f core-trims-test--deleted)
    (should-not (file-exists-p (expand-file-name f core-trims-test--root)))))

(ert-deftest core-trims/no-removed-symbols ()
  (let ((case-fold-search nil) hits)
    (dolist (f (core-trims-test--files))
      (let ((rel (file-relative-name f core-trims-test--root)))
        (with-temp-buffer
          (insert-file-contents f)
          (goto-char (point-min))
          (while (not (eobp))
            (let ((line (buffer-substring (line-beginning-position) (line-end-position))))
              (unless (string-match-p "\\`[ \t]*;" line)
                (when (or (string-match core-trims-test--plain-re line)
                          (and (string-match core-trims-test--code-re line)
                               (not (equal (cdr (assoc rel core-trims-test--allowed))
                                           (match-string 1 line)))))
                  (push (cons rel line) hits))))
            (forward-line 1)))))
    (should-not hits)))

;;; core-trims-tests.el ends here
