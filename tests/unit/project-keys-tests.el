;;; project-keys-tests.el --- the SPC p leader map -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst pkt--file
  (expand-file-name "../../modules/config/default/+evil-bindings.el"
                    (file-name-directory (or load-file-name buffer-file-name))))

(defconst pkt--expected
  '(("p" . project-switch-project) ("f" . project-find-file)
    ("b" . project-switch-to-buffer) ("k" . project-kill-buffers)
    ("s" . project-save-some-buffers) ("a" . doom/add-directory-as-project)
    ("d" . project-forget-project) ("!" . project-shell-command)
    ("&" . project-async-shell-command) ("c" . project-compile)
    ("D" . +default/discover-projects) ("F" . doom/find-file-in-other-project)
    (">" . doom/browse-in-other-project) ("." . +default/browse-project)
    ("o" . find-sibling-file) ("x" . doom/toggle-project-scratch-buffer)
    ("X" . doom/switch-to-project-scratch-buffer)))

(defun pkt--find (form)
  "Return the `(:prefix-map (\"p\" . \"project\") ...)' form nested in FORM."
  (when (consp form)
    (if (and (eq (car form) :prefix-map) (equal (cadr form) '("p" . "project")))
        form
      (cl-loop for sub on form
               when (and (consp sub) (pkt--find (car sub))) return it))))

(defun pkt--table ()
  "Key -> command pairs of the SPC p map, read from the bindings file as data."
  (let (map)
    (with-temp-buffer
      (insert-file-contents pkt--file)
      (goto-char (point-min))
      (condition-case nil
          (while (not map) (setq map (pkt--find (read (current-buffer)))))
        (end-of-file nil)))
    (let (pairs)
      ;; Entries are :desc LABEL KEY #'CMD triples.
      (let ((rest (cddr map)))
        (while rest
          (if (eq (car rest) :desc)
              (progn (push (cons (nth 2 rest) (cadr (nth 3 rest))) pairs)
                     (setq rest (nthcdr 4 rest)))
            (setq rest (cdr rest)))))
      (nreverse pairs))))

(ert-deftest project-keys/exact-table ()
  (let ((table (pkt--table)))
    (should (equal (sort (copy-sequence pkt--expected) (lambda (a b) (string< (car a) (car b))))
                   (sort (copy-sequence table) (lambda (a b) (string< (car a) (car b))))))))

(ert-deftest project-keys/dropped-keys-absent ()
  (let ((keys (mapcar #'car (pkt--table))))
    (dolist (k '("C" "R" "T" "g" "r" "e" "i"))
      (should-not (member k keys)))))
