;;; config-dir.el --- where the user's Doom config lives -*- lexical-binding: t; no-byte-compile: t; -*-

;; Shared by the unit tests that load config modules; the config is not part of this repo.

(defconst tcd-default-config-dir
  "/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite/")

(defun tcd-config-dir ()
  "The config dir ($DOOM_LITE_CONFIG or the default) with a trailing slash; signal an error if it has no init.el."
  (let ((dir (file-name-as-directory
              (expand-file-name (or (getenv "DOOM_LITE_CONFIG") tcd-default-config-dir)))))
    (unless (file-exists-p (expand-file-name "init.el" dir))
      (error "Doom config not found (set DOOM_LITE_CONFIG): %s" dir))
    dir))

(provide 'config-dir)
;;; config-dir.el ends here
