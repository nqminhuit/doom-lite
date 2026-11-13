;;; lookup-lsp-tests.el --- lsp-mode and lookup docsets/online/xwidget stay removed -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst lookup-lsp-test--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defconst lookup-lsp-test--removed-files
  '("modules/tools/lsp/+lsp.el"
    "modules/tools/lookup/autoload/docsets.el"
    "modules/tools/lookup/autoload/online.el"
    "modules/tools/lookup/autoload/xwidget.el"))

(defconst lookup-lsp-test--banned
  '("(set-docsets! " "+lookup/online" "+lookup/in-docsets" "(modulep! :tools lsp -eglot)"))

(defun lookup-lsp-test--files ()
  "Every .el file under modules/ and lisp/."
  (cl-loop for d in '("modules" "lisp")
           append (directory-files-recursively
                   (expand-file-name d lookup-lsp-test--root) "\\.el\\'")))

(ert-deftest lookup-lsp/scan-finds-files ()
  (should (lookup-lsp-test--files)))

(ert-deftest lookup-lsp/removed-files-are-gone ()
  (dolist (f lookup-lsp-test--removed-files)
    (should-not (file-exists-p (expand-file-name f lookup-lsp-test--root)))))

(ert-deftest lookup-lsp/no-callers-of-removed-features ()
  (let (hits)
    (dolist (f (lookup-lsp-test--files))
      (with-temp-buffer
        (insert-file-contents f)
        (dolist (s lookup-lsp-test--banned)
          (goto-char (point-min))
          (when (search-forward s nil t)
            (push (format "%s: %s" (file-relative-name f lookup-lsp-test--root) s) hits)))))
    (should-not hits)))

;;; lookup-lsp-tests.el ends here
