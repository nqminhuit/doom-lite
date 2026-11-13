;;; abbrev-tests.el --- ERT tests for the minh abbrev module -*- lexical-binding: t; -*-

(require 'ert)
(require 'cc-mode)

(load (expand-file-name "../../config/modules/minh/abbrev/config.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(defun abbrev-tests--in-code-p (text)
  "Return `m/abbrev-in-code-p' with point at the `|' marker in TEXT."
  (with-temp-buffer
    (java-mode)
    (insert text)
    (goto-char (point-min))
    (search-forward "|")
    (delete-char -1)
    (syntax-ppss-flush-cache (point-min))
    (m/abbrev-in-code-p)))

(ert-deftest abbrev/in-code-p-true-in-code ()
  (should (abbrev-tests--in-code-p "int x = 1; |")))

(ert-deftest abbrev/in-code-p-nil-in-string ()
  (should-not (abbrev-tests--in-code-p "String s = \"foo |bar\";")))

(ert-deftest abbrev/in-code-p-nil-in-comment ()
  (should-not (abbrev-tests--in-code-p "// foo |bar\n"))
  (should-not (abbrev-tests--in-code-p "/* foo |bar */")))

(ert-deftest abbrev/java-snippets-are-disabled-in-strings-and-comments ()
  (dolist (name '("mctor" "opnul"))
    (let ((sym (abbrev--symbol name java-ts-mode-abbrev-table)))
      (should sym)
      (should (eq (abbrev-get sym :enable-function) #'m/abbrev-in-code-p)))))

;;; abbrev-tests.el ends here
