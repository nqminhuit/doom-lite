;;; cli-commands-tests.el --- removed CLI commands stay removed -*- lexical-binding: t; -*-

(require 'ert)

(defconst clit--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defun clit--read (file)
  (with-temp-buffer
    (insert-file-contents (expand-file-name file clit--root))
    (buffer-string)))

(ert-deftest clit-doom-has-no-stubs-or-obsolete-commands ()
  (let ((text (clit--read "bin/doom")))
    (dolist (s '("defcli-stub!" "defcli-obsolete!" "doom-cli-exec-path" "(defcli! run"))
      (should-not (string-search s text)))))

(ert-deftest clit-doom-env-has-no-obsolete-commands ()
  (should-not (string-search "defcli-obsolete!" (clit--read "bin/doom-env"))))
