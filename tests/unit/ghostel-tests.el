;;; ghostel-tests.el --- the ghostel module downloads into doom-data-dir -*- lexical-binding: t; -*-

(require 'ert)

(defconst gh-test-config
  (expand-file-name "../../modules/term/ghostel/config.el"
                    (file-name-directory (or load-file-name buffer-file-name))))

(defvar doom-data-dir "/fake/data/")
(defvar ghostel-module-auto-install 'ask)
(defvar ghostel-module-directory nil)

;; Stub `use-package!' so only the :init forms run, as they do before ghostel loads.
(defmacro gh-test-use-package (_name &rest args)
  (let (forms in-init)
    (dolist (a args)
      (cond ((eq a :init) (setq in-init t))
            ((keywordp a) (setq in-init nil))
            (in-init (push a forms))))
    `(progn ,@(nreverse forms))))

(defmacro add-hook! (&rest _) nil)

(ert-deftest gh-test-module-is-downloaded-outside-the-package-tree ()
  (with-temp-buffer
    (insert-file-contents gh-test-config)
    (goto-char (point-min))
    (condition-case nil
        (while t
          (let ((form (read (current-buffer))))
            (when (eq (car-safe form) 'use-package!)
              (eval (cons 'gh-test-use-package (cdr form)) t))))
      (end-of-file nil)))
  (should (eq ghostel-module-auto-install 'download))
  (should (equal ghostel-module-directory "/fake/data/ghostel/")))
