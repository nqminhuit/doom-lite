;;; minh/abbrev/config.el -*- lexical-binding: t; -*-

(setq-default abbrev-mode t)
(setq save-abbrevs nil)

;; C-x ' to trigger expand-abbrev

(define-abbrev-table 'global-abbrev-table
  '(
    ("muuid" "" (lambda () (insert (string-trim (m/uuid)))))
    ("mtime" "" (lambda () (insert (format-time-string "%H:%M:%S %Y-%m-%d"))))))

(defun m/take-region-text ()
  "Delete the active region and return its trimmed text, or \"\" if none."
  (if (use-region-p)
      (prog1 (string-trim (buffer-substring (region-beginning) (region-end)))
        (delete-region (region-beginning) (region-end)))
    ""))

;;; go-mode

(define-skeleton m/go-clogdebug
  "Insert a debug log.Printf statement."
  "Expr: "
  "log.Printf(\"" str " = %s\\n\", " str _ ")")

(define-abbrev-table 'go-ts-mode-abbrev-table
  '(("clogdebug" "" m/go-clogdebug)))

;;; java-ts-mode

(define-skeleton m/java-aast
  "Insert an AssertJ assertThat(...).isXxx(...) assertion."
  nil
  (let* ((expr (skeleton-read "Expr: "))
         (is (skeleton-read "Is: "))
         (arg (skeleton-read "Arg: ")))
    (insert "Assertions.assertThat(" expr ").is" is "(" arg ");")))

(define-skeleton m/java-ast
  "Insert an assertThat(...).isEqualTo(); assertion."
  nil
  "assertThat(" _ ").isEqualTo();")

(define-skeleton m/java-clogdebug
  "Insert a colorized debug println statement."
  "Expr: "
  "System.out.println(\"\\u001B[33m " str " = '%s' \\u001B[0m\".formatted(" str _ "));")

(define-skeleton m/java-clogmsg
  "Insert a colorized debug message println statement."
  "Message: "
  "System.out.println(\"\\u001B[33m mmm### '" str "' \\u001B[0m\");")

(define-skeleton m/java-ctor
  "Insert a constructor for the current class."
  "Params: "
  > "public " (insert (+java-current-class)) " (" str ") {" \n
  > _ \n
  > "}")

(defun m/java-if ()
  "Wrap the region (or point) in an if block; point ends in the condition."
  (interactive "*")
  (let* ((body (m/take-region-text))
         (start (point)))
    (insert "if (")
    (let ((cond-pos (point)))
      (insert ") {\n" body "\n}")
      (indent-region start (point))
      (goto-char cond-pos))))
(put 'm/java-if 'no-self-insert t)

(defun m/java-else ()
  "Wrap the region (or point) in an else block; point starts the body."
  (interactive "*")
  (let* ((body (m/take-region-text))
         (start (point)))
    (insert "else {\n")
    (let ((body-pos (point)))
      (insert body "\n}")
      (indent-region start (point))
      (goto-char body-pos))))
(put 'm/java-else 'no-self-insert t)

(define-skeleton m/java-gwt
  "Insert a given/when/then comment scaffold."
  nil
  "// given:\n\n\n// when:\n   " _ "\n\n// then:")

(defvar m/java-instnow "Instant.now().toEpochMilli()")

(define-skeleton m/java-opnul
  "Insert `Optional.ofNullable', importing `java.util.Optional' if needed."
  nil
  (unless (save-excursion
            (goto-char (point-min))
            (re-search-forward "^import java\\.util\\.Optional;" nil t))
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "^package .*;" nil t)
          (forward-line 1)
        (goto-char (point-min)))
      (insert "\nimport java.util.Optional;\n")))
  "Optional.ofNullable" _)

(defun m/java-trycatch (exception-type)
  "Wrap the region (or point) in a try/catch block."
  (interactive (list (read-string "Exception type: ")))
  (let* ((body (m/take-region-text))
         (start (point)))
    (insert "try {\n" body "\n} catch (" exception-type "Exception e) {\n")
    (let ((catch-pos (point)))
      (insert "e.printStackTrace();\n}")
      (indent-region start (point))
      (goto-char catch-pos))))
(put 'm/java-trycatch 'no-self-insert t)

(defun m/abbrev-in-code-p ()
  "Non-nil when point is outside strings and comments."
  (not (nth 8 (syntax-ppss))))

(define-abbrev-table 'java-ts-mode-abbrev-table
  `(
    ("aast" "" m/java-aast)
    ("mast" "" m/java-ast)
    ("clogdebug" "" m/java-clogdebug)
    ("clogmsg" "" m/java-clogmsg)
    ("mctor" "" m/java-ctor :enable-function ,#'m/abbrev-in-code-p)
    ("mif" "" m/java-if)
    ("melse" "" m/java-else)
    ("gwt" "" m/java-gwt)
    ("instnow" ,m/java-instnow)
    ("opnul" "" m/java-opnul :enable-function ,#'m/abbrev-in-code-p)
    ("trycatch" "" m/java-trycatch)))

;;; js-ts-mode / typescript-ts-mode

(define-skeleton m/js-clogdebug
  "Insert a debug console.log statement."
  "Expr: "
  "console.log(\"mmm### " str " =\", " str ");")

(define-skeleton m/js-clogmsg
  "Insert a console.log statement."
  nil
  "console.log(\"" _ "\");")

(dolist (table '(js-ts-mode-abbrev-table typescript-ts-mode-abbrev-table))
  (define-abbrev-table table
    '(
      ("clogdebug" "" m/js-clogdebug)
      ("clogmsg" "" m/js-clogmsg))))
