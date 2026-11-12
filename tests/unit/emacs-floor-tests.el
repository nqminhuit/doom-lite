;;; emacs-floor-tests.el --- Emacs 31 is the minimum; old backports are gone -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst ef-test-root
  (expand-file-name "../.." (file-name-directory (or load-file-name buffer-file-name))))

(defconst ef-test-builtins
  '(ensure-list always file-name-concat with-environment-variables
    file-name-with-extension dlet with-memoization pos-bol pos-eol
    static-if static-when static-unless
    treesit-available-p treesit-library-abi-version treesit-language-abi-version
    major-mode-remap mode-line-invisible-mode))

(ert-deftest ef-test-shimmed-symbols-are-builtin ()
  (dolist (sym ef-test-builtins)
    (should (fboundp sym))))

(ert-deftest ef-test-backport-shims-removed ()
  (dolist (file '("lisp/doom-lib.el" "lisp/doom-emacs.el"))
    (with-temp-buffer
      (insert-file-contents (expand-file-name file ef-test-root))
      (dolist (sym ef-test-builtins)
        (should-not (search-forward (format "(unless (fboundp '%s)" sym) nil t))
        (goto-char (point-min))))))

(ert-deftest ef-test-doom-requires-emacs-31 ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "lisp/doom.el" ef-test-root))
    (should (re-search-forward
             "(when (< emacs-major-version 31)\n *(user-error" nil t))))

;;; emacs-floor-tests.el ends here
