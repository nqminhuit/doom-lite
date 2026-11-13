;;; packages-paths.el --- where the synced packages live -*- lexical-binding: t; no-byte-compile: t; -*-

;; Shared by tests and tests/smoke.sh. The only place that knows the packages layout.

(defun tpp-build-dir (root &optional package)
  "The build dir under ROOT's .local for this Emacs version, or PACKAGE's within it."
  (file-name-concat root ".local/packages" (format "build-%s" emacs-version) package))

(provide 'packages-paths)
;;; packages-paths.el ends here
