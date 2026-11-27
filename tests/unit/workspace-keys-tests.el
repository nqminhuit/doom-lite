;;; workspace-keys-tests.el --- workspace bindings and references -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst wkt--root
  (expand-file-name "../.." (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "tests/config-dir.el" wkt--root) nil t)

(defconst wkt--sym-re "\\(?:#'\\|'\\)\\(\\+workspaces?[/:-][^][ ()\"';#\n]*\\)")

(defun wkt--read-all (rel)
  "All top-level forms of REL (relative to the repo root), read as data."
  (with-temp-buffer
    (insert-file-contents (expand-file-name rel wkt--root))
    (goto-char (point-min))
    (let (forms)
      (condition-case nil (while t (push (read (current-buffer)) forms))
        (end-of-file nil))
      (nreverse forms))))

(defun wkt--pairs (form)
  "Collect (KEY . COMMAND) for every \"KEY\" #'CMD pair nested in FORM."
  (when (consp form)
    (append (when (and (stringp (car form)) (consp (cdr form))
                       (eq (car-safe (cadr form)) 'function))
              (list (cons (car form) (cadr (cadr form)))))
            (wkt--pairs (car form))
            (wkt--pairs (cdr form)))))

(defun wkt--find-prefix-map (form name)
  (when (consp form)
    (if (and (eq (car form) :prefix-map) (equal (cadr form) name))
        form
      (or (wkt--find-prefix-map (car form) name)
          (wkt--find-prefix-map (cdr form) name)))))

(defun wkt--file-pairs (rel)
  (wkt--pairs (wkt--read-all rel)))

(defconst wkt--evil-bindings "modules/config/default/+evil-bindings.el")

(defun wkt--check (rel expected &optional pairs)
  (let ((pairs (or pairs (wkt--file-pairs rel))))
    (dolist (e expected)
      (should (member e pairs)))))

(defun wkt--digits (fmt n)
  "Pairs for keys 1..N (via FMT) mapping to +workspace/switch-to-0..N-1."
  (cl-loop for i from 1 to n
           collect (cons (format fmt i) (intern (format "+workspace/switch-to-%d" (1- i))))))

(ert-deftest workspace-keys/leader-tab-map ()
  (let ((map (wkt--find-prefix-map (wkt--read-all wkt--evil-bindings) '("TAB" . "workspace"))))
    (should map)
    (wkt--check nil
                `(("TAB" . +workspace/display) ("." . +workspace/switch-to)
                  ("`" . +workspace/other) ("n" . +workspace/new)
                  ("N" . +workspace/new-named) ("d" . +workspace/kill)
                  ("r" . +workspace/rename) ("]" . +workspace/switch-right)
                  ("[" . +workspace/switch-left) ("0" . +workspace/switch-to-final)
                  ,@(wkt--digits "%s" 9))
                (wkt--pairs map))))

;; Step 2 extensions: dropped keys and the new session/buffer bindings.
(ert-deftest workspace-keys/leader-tab-map-changes ()
  (let* ((map (wkt--find-prefix-map (wkt--read-all wkt--evil-bindings) '("TAB" . "workspace")))
         (pairs (wkt--pairs map)))
    (dolist (k '("l" "s" "x" "D"))
      (should-not (assoc k pairs)))
    (should (member '("R" . doom/quickload-session) pairs))))

(ert-deftest workspace-keys/buffer-switching ()
  (let* ((forms (wkt--read-all wkt--evil-bindings))
         (b-map (wkt--find-prefix-map forms '("b" . "buffer")))
         (b-pairs (wkt--pairs b-map)))
    (should (member '("b" . +vertico/switch-workspace-buffer) b-pairs))
    (should (member '("B" . switch-to-buffer) b-pairs))
    (should-not (assoc "I" b-pairs))
    (wkt--check nil '(("," . +vertico/switch-workspace-buffer) ("<" . switch-to-buffer))
                (wkt--pairs forms))))

(ert-deftest workspace-keys/global-bindings ()
  (wkt--check wkt--evil-bindings
              `(("C-t" . +workspace/new) ("C-S-t" . +workspace/display)
                ,@(wkt--digits "M-%s" 9)
                ("M-0" . +workspace/switch-to-final))))

(ert-deftest workspace-keys/evil-bindings ()
  (wkt--check "modules/editor/evil/config.el"
              '(("gt" . +workspace:switch-next) ("gT" . +workspace:switch-previous)
                ("]w" . +workspace/switch-right) ("[w" . +workspace/switch-left))))

(defun wkt--files (dir)
  (directory-files-recursively (expand-file-name dir wkt--root) "\\.el\\'"))

(defun wkt--slurp (file)
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(ert-deftest workspace-keys/referenced-commands-are-defined ()
  (let* ((module-dir (file-name-as-directory (expand-file-name "modules/ui/workspaces" wkt--root)))
         (defs (mapconcat #'wkt--slurp (wkt--files "modules/ui/workspaces") "\n"))
         (loop-p (string-match-p "\\+workspace/switch-to-%d" defs))
         (refs nil))
    (dolist (file (append (wkt--files "modules") (wkt--files "lisp") (wkt--files (tcd-config-dir))))
      (unless (string-prefix-p module-dir file)
        (dolist (line (split-string (wkt--slurp file) "\n"))
          (unless (string-match-p "\\`[ \t]*;" line)
            (let ((pos 0))
              (while (string-match wkt--sym-re line pos)
                (push (match-string 1 line) refs)
                (setq pos (match-end 0))))))))
    (should refs)
    (dolist (sym (delete-dups refs))
      (should (or (string-match-p
                   (concat "\\(?:(\\(?:defun\\|defmacro\\|defvar\\|defcustom\\|evil-define-command\\)[ \t]+"
                           "\\|(defalias[ \t]+#?'\\)" (regexp-quote sym) "[ \t\n)]")
                   defs)
                  (and loop-p (string-match "\\`\\+workspace/switch-to-\\([0-8]\\)\\'" sym)))))))
