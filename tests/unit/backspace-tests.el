;;; backspace-tests.el --- tab-column backspace behavior -*- lexical-binding: t; -*-

(require 'ert)

(defconst bt--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defun bt--path (rel) (expand-file-name rel bt--root))

(load (bt--path "lisp/doom-lib.el") nil t)
(unless (fboundp 'modulep!) (defmacro modulep! (&rest _) nil))
(load (bt--path "lisp/lib/text.el") nil t)
(load (bt--path "modules/config/default/autoload/text.el") nil t)

(defmacro bt--with-buffer (content &rest body)
  "Run BODY in a temp buffer holding CONTENT, point at the \"|\" marker."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,content)
     (goto-char (point-min))
     (search-forward "|")
     (delete-char -1)
     (setq-local indent-tabs-mode nil)
     (setq-local tab-width 4)
     ,@body))

(ert-deftest backspace/tab-column ()
  (bt--with-buffer "      |x"
    (+default--delete-backward-char-a 1)
    (should (equal (buffer-string) "    x"))
    (+default--delete-backward-char-a 1)
    (should (equal (buffer-string) "x"))))

(ert-deftest backspace/plain-char ()
  (bt--with-buffer "abc|d"
    (+default--delete-backward-char-a 1)
    (should (equal (buffer-string) "abd"))))

(ert-deftest backspace/n-chars ()
  (bt--with-buffer "abcd|e"
    (+default--delete-backward-char-a 3)
    (should (equal (buffer-string) "ae"))))

(ert-deftest backspace/region ()
  (bt--with-buffer "ab|cdef"
    (let ((transient-mark-mode t)
          (delete-active-region t))
      (set-mark 2)
      (goto-char 5)
      (activate-mark)
      (+default--delete-backward-char-a 1)
      (should (equal (buffer-string) "aef")))))

(ert-deftest backspace/in-string ()
  (bt--with-buffer "(\"      |\")"
    (emacs-lisp-mode)
    (setq-local indent-tabs-mode nil tab-width 4)
    (should (doom-point-in-string-p))
    (+default--delete-backward-char-a 1)
    (should (equal (buffer-string) "(\"     \")"))))

;;; backspace-tests.el ends here
