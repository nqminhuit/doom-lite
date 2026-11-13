;;; startup-tests.el --- plain startup buffer -*- lexical-binding: t; -*-

(require 'ert)
(require 'calendar)
(require 'cl-lib)

(defconst st--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "tests/config-dir.el" st--root) nil t)
(load (expand-file-name "modules/minh/dashboard/config.el" (tcd-config-dir)) nil t)

(defmacro st--with-buffer (&rest body)
  "Run BODY, then kill the startup buffer."
  `(unwind-protect (progn ,@body)
     (when (get-buffer m-startup-buffer-name)
       (kill-buffer m-startup-buffer-name))))

(defun st--buffer-string-no-props ()
  (buffer-substring-no-properties (point-min) (point-max)))

(defun st--display-at (pos)
  (get-text-property pos 'display))

(ert-deftest startup-insert-centered-ascii ()
  (with-temp-buffer
    (m--insert-centered "abcdef")
    (should (equal (st--buffer-string-no-props) " abcdef\n"))
    (should (equal (st--display-at 1) '(space :align-to (- center 3))))))

(ert-deftest startup-insert-centered-uses-string-width ()
  (let* ((line "🗓️ November 2026")
         (n (/ (string-width line) 2)))
    (should-not (= (string-width line) (length line)))
    (with-temp-buffer
      (m--insert-centered line)
      (should (equal (st--buffer-string-no-props) (concat " " line "\n")))
      (should (equal (st--display-at 1) `(space :align-to (- center ,n)))))))

(ert-deftest startup-insert-centered-multiple-lines ()
  (with-temp-buffer
    (m--insert-centered "a" "b")
    (should (equal (st--buffer-string-no-props) " a\n b\n"))))

(ert-deftest startup-buffer-state ()
  (st--with-buffer
   (let ((buf (m-startup-buffer)))
     (should (buffer-live-p buf))
     (should (equal (buffer-name buf) m-startup-buffer-name))
     (with-current-buffer buf
       (should (eq major-mode 'm-startup-mode))
       (should buffer-read-only)
       (should-not mode-line-format)
       (should-not hl-line-mode)
       (should-not (derived-mode-p 'prog-mode 'text-mode 'conf-mode 'special-mode))))))

(ert-deftest startup-buffer-contents ()
  (st--with-buffer
   (with-current-buffer (m-startup-buffer)
     (let ((s (st--buffer-string-no-props))
           (now (decode-time (current-time))))
       (should (string-match-p (regexp-quote "|_____|") s))
       (should (string-match-p "packages" s))
       (should (string-match-p (regexp-quote (calendar-month-name (nth 4 now))) s))
       (should (string-match-p (number-to-string (nth 5 now)) s))))))

(ert-deftest startup-buffer-rebuild-is-idempotent ()
  (st--with-buffer
   (let ((first (m-startup-buffer))
         size)
     (setq size (buffer-size first))
     (let ((second (m-startup-buffer)))
       (should (eq first second))
       (should (= size (buffer-size second)))
       (with-current-buffer second
         (should (= 1 (how-many (regexp-quote "|_____|") (point-min) (point-max)))))))))

(ert-deftest startup-today-is-highlighted ()
  (st--with-buffer
   (with-current-buffer (m-startup-buffer)
     (let ((pos (point-min)) found)
       (while (and (not found) (setq pos (next-single-property-change pos 'face)))
         (when (equal (get-text-property pos 'face) '(:inverse-video t))
           (setq found (string-trim
                        (buffer-substring-no-properties
                         pos (next-single-property-change pos 'face))))))
       (should (equal found (number-to-string (nth 3 (decode-time (current-time))))))))))

(defun st--valid-face-p (face)
  "Non-nil if FACE is a face spec Emacs can render without an invalid-face error."
  (cond ((symbolp face) (facep face))
        ((consp face) (or (keywordp (car face))
                          (cl-every (lambda (f) (or (not (symbolp f)) (facep f))) face)))))

(ert-deftest startup-buffer-faces-are-defined ()
  (st--with-buffer
   (with-current-buffer (m-startup-buffer)
     (let ((pos (point-min)))
       (while (setq pos (next-single-property-change pos 'face))
         (let ((face (get-text-property pos 'face)))
           (when face
             (should (st--valid-face-p face)))))))))

(ert-deftest startup-initial-buffer-choice ()
  (should (eq initial-buffer-choice #'m-startup-buffer)))

;;; startup-tests.el ends here
