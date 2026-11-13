;;; minh-autoload-tests.el --- bound minh commands autoload without loading their files -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'loaddefs-gen)

(defconst minh-autoload-test--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defun minh-autoload-test--files (regexp)
  (directory-files-recursively (expand-file-name "config" minh-autoload-test--root) regexp))

(defun minh-autoload-test--defuns ()
  "Every `defun' name in the minh autoload.el files."
  (let (names)
    (dolist (f (minh-autoload-test--files "\\`autoload\\.el\\'"))
      (with-temp-buffer
        (insert-file-contents f)
        (while (re-search-forward "^(defun \\([^ ()]+\\)" nil t)
          (push (match-string 1) names))))
    names))

(defun minh-autoload-test--interactive-defuns ()
  "Every interactive `defun' name in the minh autoload.el files."
  (let (names)
    (dolist (f (minh-autoload-test--files "\\`autoload\\.el\\'"))
      (with-temp-buffer
        (insert-file-contents f)
        (while (re-search-forward "^(defun " nil t)
          (goto-char (match-beginning 0))
          (let ((form (read (current-buffer))))
            (when (assq 'interactive (nthcdr 3 form))
              (push (symbol-name (cadr form)) names))))))
    names))

(defun minh-autoload-test--bound ()
  "Defuns from the autoload files that the config quotes with ' or #'."
  (let ((defs (minh-autoload-test--defuns)) quoted)
    (dolist (f (cl-remove-if (lambda (f) (string-match-p "/autoload\\.el\\'" f))
                             (minh-autoload-test--files "\\.el\\'")))
      (with-temp-buffer
        (insert-file-contents f)
        (while (re-search-forward "#?'\\([^][:space:]()\"']+\\)" nil t)
          (push (match-string 1) quoted))))
    (sort (delete-dups (cl-remove-if-not (lambda (n) (member n quoted)) defs)) #'string<)))

(ert-deftest minh-autoload/scan-finds-bound-commands ()
  (let ((bound (minh-autoload-test--bound)))
    (dolist (c '("m/catcmd" "m/select-text-line" "gis/find-modified-files"))
      (should (member c bound)))))

(defun minh-autoload-test--missing-after-loaddefs (symbols)
  "Names in SYMBOLS that are not `fboundp' after loading only generated loaddefs."
  (let ((out (make-temp-file "minh-loaddefs" nil ".el"))
        (dirs (mapcar #'file-name-directory (minh-autoload-test--files "\\`autoload\\.el\\'")))
        missing)
    (unwind-protect
        (progn
          (loaddefs-generate dirs out nil nil nil t)
          (let ((emacs (expand-file-name invocation-name invocation-directory)))
            (with-temp-buffer
              (let ((status (call-process
                             emacs nil t nil "--batch" "-Q" "-l" out "--eval"
                             (format "(let (m) (dolist (s '%S) (unless (fboundp (intern s)) (push s m))) (princ (format \"%%S\" m)))"
                                     symbols))))
                (should (eq status 0))
                (setq missing (car (read-from-string (buffer-string))))))))
      (delete-file out))
    missing))

(ert-deftest minh-autoload/bound-commands-are-fboundp-from-loaddefs-alone ()
  (should-not (minh-autoload-test--missing-after-loaddefs (minh-autoload-test--bound))))

(ert-deftest minh-autoload/all-interactive-commands-are-fboundp-from-loaddefs-alone ()
  (let ((cmds (minh-autoload-test--interactive-defuns)))
    (dolist (c '("gis/create-branch" "gis/push" "gis/fetch" "gis/pull" "cm/switch-cloud-or-onprem"))
      (should (member c cmds)))
    (should-not (minh-autoload-test--missing-after-loaddefs cmds))))

(ert-deftest minh-autoload/no-dead-autodef-cookies ()
  (dolist (f (minh-autoload-test--files "\\`autoload\\.el\\'"))
    (with-temp-buffer
      (insert-file-contents f)
      (should-not (search-forward ";;;###autodef" nil t)))))

;;; minh-autoload-tests.el ends here
