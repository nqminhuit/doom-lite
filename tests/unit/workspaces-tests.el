;;; workspaces-tests.el --- tab-bar workspace behavior -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst wst--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(defun wst--path (rel) (expand-file-name rel wst--root))

(load (wst--path "lisp/doom-lib.el") nil t)
(unless (boundp 'doom-profile-state-dir)
  (defvar doom-profile-state-dir (make-temp-file "wst-state" t)))
(load (wst--path "lisp/doom-projects.el") nil t)
(load (wst--path "lisp/lib/projects.el") nil t)
(defvar doom-fallback-buffer-name "*scratch*")
(load (wst--path "lisp/lib/buffers.el") nil t)
(defvar +workspaces-main "main")
(defvar +workspaces-switch-project-function #'ignore)
(load (wst--path "modules/ui/workspaces/autoload/workspaces.el") nil t)

(defvar wst--base nil)

(defmacro wst--with-fixture (&rest body)
  "Run BODY in a single `main' tab, with project state isolated from the user's."
  (declare (indent 0))
  `(progn
     (unless (executable-find "git") (ert-skip "git missing"))
     (let* ((wst--base (file-name-as-directory (file-truename (make-temp-file "wst-base" t))))
            ;; Fixtures must live outside `temporary-file-directory' (ignored as a project).
            (temporary-file-directory (file-truename (make-temp-file "wst-tmp" t)))
            (project-list-file (expand-file-name "projects" temporary-file-directory))
            (default-directory wst--base)
            (+workspaces--project-roots nil)
            (tab-bar-show nil)
            (+workspaces-switch-project-function #'ignore))
       (unwind-protect
           (progn
             (set-frame-parameter nil 'tabs nil)
             (delete-other-windows)
             (switch-to-buffer "*scratch*")
             (tab-bar-rename-tab "main")
             ,@body)
         (set-frame-parameter nil 'tabs nil)
         (delete-directory wst--base t)
         (delete-directory temporary-file-directory t)))))

(defun wst--repo (rel)
  "Create a git repo at REL under `wst--base'; return its root."
  (let ((root (file-name-as-directory (expand-file-name rel wst--base))))
    (make-directory root t)
    (let ((default-directory root)) (call-process "git" nil nil nil "init" "-q"))
    (file-truename root)))

(defun wst--names () (+workspace-list-names))

(ert-deftest workspaces/project-creates-reuses-recycles ()
  (wst--with-fixture
    (let ((a (wst--repo "a")))
      ;; Recyclable main is renamed, not duplicated.
      (+workspaces-switch-to-project-h a)
      (should (equal (wst--names) '("a")))
      ;; A second project gets its own tab; switching back reuses.
      (let ((b (wst--repo "b")))
        (+workspaces-switch-to-project-h b)
        (should (equal (wst--names) '("a" "b")))
        (+workspaces-switch-to-project-h a)
        (should (equal (wst--names) '("a" "b")))
        (should (equal (+workspace-current-name) "a"))))))

(ert-deftest workspaces/project-adds-tab-when-main-in-use ()
  (wst--with-fixture
    (let ((file (expand-file-name "f.txt" wst--base)))
      (write-region "" nil file)
      (find-file file)
      (+workspaces-switch-to-project-h (wst--repo "a"))
      (should (equal (wst--names) '("main" "a")))
      (kill-buffer (get-file-buffer file)))))

(ert-deftest workspaces/same-basename-distinct-tabs ()
  (wst--with-fixture
    (let ((x (wst--repo "one/app")) (y (wst--repo "two/app")))
      (+workspaces-switch-to-project-h x)
      (+workspaces-switch-to-project-h y)
      (should (= 2 (length (wst--names))))
      (should (equal (+workspace-current-name) "two/app"))
      (+workspaces-switch-to-project-h x)
      (should (equal (+workspace-current-name) "app"))
      (should (= 2 (length (wst--names)))))))

(ert-deftest workspaces/switch-project-function-gets-root ()
  (wst--with-fixture
    (let* ((a (wst--repo "a")) got
           (+workspaces-switch-project-function (lambda (d) (push d got))))
      (+workspaces-switch-to-project-h a)
      (should (equal got (list (file-name-as-directory a)))))))

(ert-deftest workspaces/switch-to-n ()
  (wst--with-fixture
    (+workspace/new) (+workspace/new)
    (should (equal (wst--names) '("main" "#1" "#2")))
    (+workspace/switch-to-0)
    (should (equal (+workspace-current-name) "main"))
    (+workspace/switch-to-2)
    (should (equal (+workspace-current-name) "#2"))
    ;; Out of range: no signal, no change.
    (+workspace/switch-to-7)
    (should (equal (+workspace-current-name) "#2"))
    (+workspace/switch-to-final)
    (should (equal (+workspace-current-name) "#2"))))

(ert-deftest workspaces/new-rename-kill ()
  (wst--with-fixture
    (+workspace/new)
    (+workspace/new)
    (should (equal (wst--names) '("main" "#1" "#2")))
    (+workspace/rename "work")
    (should (equal (wst--names) '("main" "#1" "work")))
    (+workspace/kill "#1")
    (should (equal (wst--names) '("main" "work")))
    (+workspace/new)
    (should (member "#1" (wst--names)))
    ;; Duplicate names are refused.
    (+workspace/new "work")
    (should (= 1 (cl-count "work" (wst--names) :test #'equal)))))

(ert-deftest workspaces/kill-last-keeps-one ()
  (wst--with-fixture
    (+workspace/kill)
    (should (equal (wst--names) '("main")))
    (+workspace/kill "nope")
    (should (equal (wst--names) '("main")))))

(ert-deftest workspaces/cycle-wraps ()
  (wst--with-fixture
    (+workspace/switch-right)
    (should (equal (+workspace-current-name) "main"))
    (+workspace/new)
    (+workspace/switch-right)
    (should (equal (+workspace-current-name) "main"))
    (+workspace/switch-left)
    (should (equal (+workspace-current-name) "#1"))))

(ert-deftest workspaces/display-lists-all-tabs ()
  (wst--with-fixture
    (+workspace/new "alpha")
    (let ((out (substring-no-properties (+workspace--tabline))))
      (should (string-match-p "\\[1\\] main" out))
      (should (string-match-p "\\[2\\] alpha" out)))
    (should (= 0 (frame-parameter nil 'tab-bar-lines)))))

(ert-deftest workspaces/init-frame-names-first-tab ()
  (wst--with-fixture
    (tab-bar-rename-tab "x")
    (set-frame-parameter nil 'tabs nil)
    (+workspaces-init-frame-h)
    (should (equal (wst--names) '("main")))))

(defun wst--messages-have-renamed-p ()
  (with-current-buffer "*Messages*"
    (save-excursion (goto-char (point-min))
                    (search-forward "Renamed tab to" nil t))))

(ert-deftest workspaces/no-tab-renamed-message ()
  (wst--with-fixture
    (with-current-buffer "*Messages*" (let ((inhibit-read-only t)) (erase-buffer)))
    (set-frame-parameter nil 'tabs nil)
    (+workspaces-init-frame-h)
    (+workspace/new "other")
    (+workspace/rename "other2")
    (should-not (wst--messages-have-renamed-p))))
