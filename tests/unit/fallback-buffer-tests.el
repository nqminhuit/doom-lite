;;; fallback-buffer-tests.el --- plain startup/fallback buffer -*- lexical-binding: t; -*-

(require 'ert)

(defconst fbt--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "lisp/doom-lib.el" fbt--root) nil t)
(load (expand-file-name "lisp/lib/buffers.el" fbt--root) nil t)

(ert-deftest fallback-buffer-name-is-scratch ()
  (should (equal doom-fallback-buffer-name "*scratch*")))

(ert-deftest fallback-buffer-is-live-scratch ()
  (let ((buf (doom-fallback-buffer)))
    (should (buffer-live-p buf))
    (should (equal (buffer-name buf) "*scratch*"))))

;;; fallback-buffer-tests.el ends here
