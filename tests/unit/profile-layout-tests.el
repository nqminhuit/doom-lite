;;; profile-layout-tests.el --- the single built-in profile's files stay where they are -*- lexical-binding: t; -*-

(require 'ert)

(defconst pl2-test-root
  (expand-file-name "../.." (file-name-directory (or load-file-name buffer-file-name))))

(defvar doom-local-dir (file-name-as-directory (make-temp-file "pl2-local" t)))
(defvar doom-data-dir (expand-file-name "etc/" doom-local-dir))

(add-hook 'kill-emacs-hook (lambda () (delete-directory doom-local-dir t)))

(load (expand-file-name "lisp/doom.el" pl2-test-root) nil t)
(load (expand-file-name "lisp/doom-lib.el" pl2-test-root) nil t)
(load (expand-file-name "lisp/doom-profiles.el" pl2-test-root) nil t)

(ert-deftest profile-layout/init-file ()
  (should (equal (doom-profile-init-file doom--profile-default)
                 (expand-file-name (format "@/init.%d.%d.el" emacs-major-version emacs-minor-version)
                                   doom-data-dir))))

(ert-deftest profile-layout/envvar-file ()
  (should (equal (doom-profile-dir doom--profile-default doom-profile-init-dir-name "05-doom-env.load.el")
                 (expand-file-name "init.d/05-doom-env.load.el" doom-data-dir))))

(ert-deftest profile-layout/init-dir ()
  (should (equal (doom-profile-init-dir doom--profile-default doom-profile-init-dir-name)
                 (expand-file-name "@/init.d" doom-data-dir))))

;;; profile-layout-tests.el ends here
