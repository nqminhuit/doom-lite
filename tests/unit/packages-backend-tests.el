;;; packages-backend-tests.el --- the clone-at-pin package backend -*- lexical-binding: t; -*-

;; Everything runs against temp `file://' git repos created here; no network, no sync.

(require 'ert)
(require 'cl-lib)

(defconst pb-test-root
  (expand-file-name "../.." (file-name-directory (or load-file-name buffer-file-name))))

(defvar doom-emacs-dir (file-name-as-directory pb-test-root))
(defvar doom-core-dir (expand-file-name "lisp/" pb-test-root))
(defvar doom-user-dir (file-name-as-directory (make-temp-file "pb-user" t)))
(defvar doom-data-dir (file-name-as-directory (make-temp-file "pb-data" t)))
(defvar doom--system-windows-p nil)
(defvar doom-module-load-path nil)

(add-hook 'kill-emacs-hook
          (lambda ()
            (delete-directory doom-user-dir t)
            (delete-directory doom-data-dir t)))

;; The CLI's output macros are not loaded here.
(unless (fboundp 'print!)
  (defmacro print! (&rest _) nil)
  (defmacro print-group! (&rest body) (macroexp-progn body)))

(load (expand-file-name "lisp/doom-lib.el" pb-test-root) nil t)
(load (expand-file-name "lisp/lib/files.el" pb-test-root) nil t)
(load (expand-file-name "lisp/lib/process.el" pb-test-root) nil t)
(load (expand-file-name "lisp/doom-modules.el" pb-test-root) nil t)
(load (expand-file-name "lisp/doom-packages.el" pb-test-root) nil t)
(defun doom-version () "0")
(load (expand-file-name "lisp/doom-profiles.el" pb-test-root) nil t)

(defconst pb-test-packages-file "/fake/modules/packages.el")
(defconst pb-test-git-env
  '("GIT_CONFIG_GLOBAL=/dev/null" "GIT_CONFIG_NOSYSTEM=1"
    "GIT_AUTHOR_NAME=t" "GIT_AUTHOR_EMAIL=t@example.com"
    "GIT_COMMITTER_NAME=t" "GIT_COMMITTER_EMAIL=t@example.com"))
(defconst pb-test-pin-1 "1111111111111111111111111111111111111111")
(defconst pb-test-pin-2 "2222222222222222222222222222222222222222")
(defconst pb-test-version "1.0")
(defconst pb-test-head "HEAD")
(defconst pb-test-foo-main "foo.el")
(defconst pb-test-pin-error "full 40-character :pin")
(defconst pb-test-data-file "data/b.txt")
(defconst pb-test-shadowed-library "tabulated-list")

(defvar pb-test--root nil "The temp dir of the running test, with a trailing slash.")


;;; Fixtures

(defun pb-test--git (dir &rest args)
  (let ((default-directory (file-name-as-directory dir))
        (process-environment (append pb-test-git-env process-environment)))
    (with-temp-buffer
      (unless (zerop (apply #'call-process "git" nil t nil args))
        (error "git %S failed: %s" args (buffer-string)))
      (string-trim (buffer-string)))))

(defmacro pb-test--with-env (&rest body)
  "Run BODY with the package dir and the remotes redirected into a temp dir."
  (declare (indent 0))
  `(let* ((pb-test--root (file-name-as-directory (make-temp-file "pb-test" t)))
          (doom-packages-dir (concat pb-test--root "pk/"))
          (doom-packages-host-urls
           (list (cons 'github (format "file://%sup/%%s.git" pb-test--root))
                 (cons 'codeberg (format "file://%sup/%%s.git" pb-test--root))))
          (doom-packages nil)
          (doom-disabled-packages nil)
          (doom-packages--full-fetches nil)
          (doom-packages--last-build-order nil))
     (unwind-protect (progn ,@body)
       (delete-directory pb-test--root t))))

(defun pb-test--upstream-dir (repo)
  (concat pb-test--root "up/" repo ".git/"))

(defun pb-test--commit (repo files)
  "Commit FILES ((PATH . TEXT) ...) to the upstream REPO and return the new HEAD."
  (let ((dir (pb-test--upstream-dir repo)))
    (unless (file-directory-p (concat dir ".git"))
      (make-directory dir t)
      (pb-test--git dir "init" "--quiet"))
    (pcase-dolist (`(,path . ,text) files)
      (let ((file (expand-file-name path dir)))
        (make-directory (file-name-directory file) t)
        (with-temp-file file (insert text))))
    (pb-test--git dir "add" "-A")
    (pb-test--git dir "commit" "--quiet" "-m" "x")
    (pb-test--git dir "rev-parse" pb-test-head)))

(defun pb-test--lib (name &optional requires body)
  "FILES for a repo whose main file is NAME.el, requiring REQUIRES ((DEP \"V\") ...)."
  (list (cons (format "%s.el" name)
              (format ";;; %1$s.el --- test -*- lexical-binding: t -*-\n;; Package-Requires: %2$s\n;;; Code:\n;;;###autoload\n(defun %1$s-hello () 1)\n%3$s(provide '%1$s)\n"
                      name (prin1-to-string (cons '(emacs "28.1")
                                                                (mapcar (lambda (r) (if (consp r) r (list r pb-test-version)))
                                                                        requires))) (or body "")))))

(defun pb-test--decl (name pin &optional recipe plist)
  "A `doom-packages' entry for NAME at PIN; RECIPE and PLIST add to the defaults."
  `(,name :pin ,pin
          :recipe ,(append recipe (list :host 'github :repo (format "o/%s" name)))
          :declared-in ,pb-test-packages-file
          ,@plist))

(defun pb-test--package (name &optional requires recipe)
  "Create upstream o/NAME and return its declaration."
  (pb-test--decl name (pb-test--commit (format "o/%s" name) (pb-test--lib name requires)) recipe))

(defun pb-test--head (repo)
  (pb-test--git (doom-packages--repos-dir repo) "rev-parse" pb-test-head))

(defun pb-test--error (thunk)
  "Call THUNK, which must signal a `doom-package-error', and return its message."
  (error-message-string (should-error (funcall thunk) :type 'doom-package-error)))

(defun pb-test--listing (package)
  "Files in PACKAGE's build dir, relative to it, without byte-code or autoloads."
  (let ((dir (doom-packages--build-dir package)))
    (sort (cl-loop for file in (directory-files-recursively dir "")
                   for rel = (file-relative-name file dir)
                   unless (string-match-p "\\.elc\\'\\|-autoloads\\.el\\'" rel)
                   collect rel)
          #'string<)))


;;; Checkout, pins and incremental rebuilds

(ert-deftest pb-test-checkout-at-pin-and-incremental-rebuild ()
  (pb-test--with-env
    (let* ((c (pb-test--package 'c))
           (b (pb-test--package 'b '(a)))
           (a (pb-test--package 'a)))
      (setq doom-packages (list c b a))
      (should-not (doom-packages-ensure))
      (dolist (decl (list a b c))
        (should (equal (pb-test--head (symbol-name (car decl))) (plist-get (cdr decl) :pin))))
      (should-not doom-packages--full-fetches)
      (should (= 1 (string-to-number (pb-test--git (doom-packages--repos-dir "a") "rev-list" "--count" pb-test-head))))
      (should (file-exists-p (expand-file-name "a.elc" (doom-packages--build-dir 'a))))
      (should (equal (sort (copy-sequence doom-packages--last-build-order) #'string<) '(a b c)))
      ;; Nothing changed: nothing is rebuilt.
      (doom-packages-ensure)
      (should-not doom-packages--last-build-order)
      ;; Moving a's pin moves its checkout and rebuilds a and b, but not c.
      (let ((new (pb-test--commit "o/a" '(("a.el" . ";;; a.el --- new -*- lexical-binding: t -*-\n;; Package-Requires: ((emacs \"28.1\"))\n;;; Code:\n(provide 'a)\n")))))
        (doom-package-set 'a :pin new)
        (doom-packages-ensure)
        (should (equal (pb-test--head "a") new))
        (should (equal doom-packages--last-build-order '(a b)))))))

(ert-deftest pb-test-falls-back-to-a-full-fetch ()
  (pb-test--with-env
    (let ((a (pb-test--package 'a))
          (git (symbol-function 'doom-packages--git)))
      (setq doom-packages (list a))
      (cl-letf (((symbol-function 'doom-packages--git)
                 (lambda (dir &rest args)
                   (if (member "--depth" args)
                       (cons 1 "no shallow fetch by sha")
                     (apply git dir args)))))
        (doom-packages-ensure))
      (should (equal doom-packages--full-fetches '("a")))
      (should (equal (pb-test--head "a") (plist-get (cdr a) :pin))))))


;;; Stage 1: before any network access

(defun pb-test--stage-1 (bad regexp)
  "The declaration BAD must fail with a message matching REGEXP before anything is fetched."
  (pb-test--with-env
    (let ((good (pb-test--package 'good)))
      (setq doom-packages (list good bad))
      (let ((msg (pb-test--error #'doom-packages-ensure)))
        (should (string-match-p (regexp-quote (symbol-name (car bad))) msg))
        (should (string-match-p (regexp-quote pb-test-packages-file) msg))
        (should (string-match-p regexp msg)))
      (should-not (file-exists-p (doom-packages--repos-dir))))))

(ert-deftest pb-test-unpinned-package-fails-before-fetch ()
  (pb-test--stage-1 (pb-test--decl 'bad nil) pb-test-pin-error))

(ert-deftest pb-test-short-pin-fails-before-fetch ()
  (pb-test--stage-1 (pb-test--decl 'bad "abc1234") pb-test-pin-error))

(ert-deftest pb-test-non-hex-pin-fails-before-fetch ()
  (pb-test--stage-1 (pb-test--decl 'bad (make-string 40 ?g)) pb-test-pin-error))

(ert-deftest pb-test-unknown-recipe-key-fails-before-fetch ()
  (pb-test--stage-1 (pb-test--decl 'bad pb-test-pin-1 '(:build (:not compile))) "unknown recipe key :build"))

(ert-deftest pb-test-missing-repo-fails-before-fetch ()
  (pb-test--stage-1 `(bad :pin ,pb-test-pin-1 :recipe (:host github) :declared-in ,pb-test-packages-file)
                    ":repo must be"))

(ert-deftest pb-test-shared-repo-with-different-pins-fails-before-fetch ()
  (pb-test--stage-1 (pb-test--decl 'bad pb-test-pin-2 '(:repo "o/good")) "different commit"))


;;; Stage 2: after checkout, before any build

(defun pb-test--stage-2 (requires extra-decls regexp)
  "A package `x' requiring REQUIRES must fail with REGEXP once checked out, before any build."
  (pb-test--with-env
    (let ((x (pb-test--package 'x requires)))
      (setq doom-packages (cons x extra-decls))
      (let ((msg (pb-test--error #'doom-packages-ensure)))
        (should (string-match-p "\\bx\\b" msg))
        (should (string-match-p (regexp-quote pb-test-packages-file) msg))
        (should (string-match-p regexp msg)))
      (should (file-directory-p (doom-packages--repos-dir "x")))
      (should-not (file-exists-p (doom-packages--build-root))))))

(ert-deftest pb-test-undeclared-dependency-fails-after-checkout ()
  (pb-test--stage-2 '(ghost) nil "ghost, which is not declared"))

(ert-deftest pb-test-disabled-dependency-fails-after-checkout ()
  (pb-test--stage-2 '(ghost) `((ghost :disable t :declared-in ,pb-test-packages-file))
                    "ghost, which is disabled"))

(ert-deftest pb-test-old-built-in-fails-after-checkout ()
  (pb-test--stage-2 '((transient "99.0"))
                    `((transient :built-in t :ignore t :declared-in ,pb-test-packages-file))
                    "needs transient 99.0 but Emacs provides"))

(ert-deftest pb-test-emacs-libraries-and-built-ins-satisfy-dependencies ()
  (pb-test--with-env
    (let ((x (pb-test--package 'x '((cl-lib "0.5") (nadvice "0.3") (transient "0.1")))))
      (setq doom-packages (list x `(transient :built-in t :ignore t :declared-in ,pb-test-packages-file)))
      (should-not (doom-packages-ensure))
      (should (file-directory-p (doom-packages--build-dir 'x))))))


;;; Build order

(ert-deftest pb-test-dependencies-are-built-before-dependents ()
  (pb-test--with-env
    (let* ((c (pb-test--package 'c '(b)))
           (b (pb-test--package 'b '(a)))
           (a (pb-test--package 'a)))
      (setq doom-packages (list c b a))
      (doom-packages-ensure)
      (should (equal doom-packages--last-build-order '(a b c))))))

(ert-deftest pb-test-dependency-cycle-is-an-error ()
  (pb-test--with-env
    (setq doom-packages (list (pb-test--package 'a '(b)) (pb-test--package 'b '(a))))
    (should (string-match-p "dependency cycle: a -> b -> a" (pb-test--error #'doom-packages-ensure)))
    (should-not (file-exists-p (doom-packages--build-root)))))

(ert-deftest pb-test-compile-failure-is-reported-and-retried ()
  (pb-test--with-env
    (let ((x (pb-test--decl 'x (pb-test--commit "o/x" (pb-test--lib 'x nil "(eval-when-compile (error \"boom\"))\n")))))
      (setq doom-packages (list x))
      (should (equal (doom-packages-ensure) '(x)))
      ;; A failed build is not recorded, so the next sync tries it again.
      (doom-packages-ensure)
      (should (equal doom-packages--last-build-order '(x))))))


;;; Build dir layout

(defconst pb-test-files-repo
  `((,pb-test-foo-main . ";;; foo.el --- x -*- lexical-binding: t -*-\n;;; Code:\n(provide 'foo)\n")
    ("foo-test.el" . "(provide 'foo-test)\n")
    ("foo-pkg.el" . "(define-package \"foo\" \"1\" \"x\")\n")
    ("lisp/extra.el" . ";;; extra.el --- x -*- lexical-binding: t -*-\n(provide 'extra)\n")
    ("extensions/foo-ext.el" . ";;; foo-ext.el --- x -*- lexical-binding: t -*-\n(provide 'foo-ext)\n")
    (,pb-test-data-file . "b")
    ("data/icons/a.txt" . "a")
    ("README.md" . "x")))

(defun pb-test--build-foo (recipe)
  "Build package foo from `pb-test-files-repo' with RECIPE and return its sorted listing."
  (let ((pin (pb-test--commit "o/foo" pb-test-files-repo)))
    (setq doom-packages (list (pb-test--decl 'foo pin recipe)))
    (should-not (doom-packages-ensure))
    (pb-test--listing 'foo)))

(ert-deftest pb-test-default-files-drop-tests-and-pkg-files ()
  (pb-test--with-env
    (should (equal (pb-test--build-foo nil) (list "extra.el" pb-test-foo-main)))
    (should (file-exists-p (expand-file-name "foo.elc" (doom-packages--build-dir 'foo))))))

(ert-deftest pb-test-files-globs-defaults-excludes-and-directories ()
  (pb-test--with-env
    (should (equal (pb-test--build-foo
                    '(:files (:defaults "extensions/foo-*.el" "data" (:exclude "lisp/extra.el"))))
                   (list pb-test-data-file "data/icons/a.txt" "foo-ext.el" pb-test-foo-main)))
    (let ((dir (doom-packages--build-dir 'foo)))
      ;; A directory entry is a real directory of file symlinks, so byte-code never lands in the checkout.
      (should-not (file-symlink-p (expand-file-name "data" dir)))
      (should (file-symlink-p (expand-file-name pb-test-data-file dir)))
      (should (file-symlink-p (expand-file-name pb-test-foo-main dir))))
    (should-not (cl-remove-if-not (lambda (f) (string-suffix-p ".elc" f))
                                  (directory-files-recursively (doom-packages--repos-dir "foo") "")))))

(ert-deftest pb-test-explicit-files-select-only-those ()
  (pb-test--with-env
    (should (equal (pb-test--build-foo (list :files (list pb-test-foo-main))) (list pb-test-foo-main)))))

(ert-deftest pb-test-compile-nil-leaves-no-byte-code ()
  (pb-test--with-env
    (pb-test--build-foo '(:compile nil))
    (should-not (directory-files-recursively (doom-packages--build-dir 'foo) "\\.elc\\'"))
    (should (file-exists-p (expand-file-name pb-test-foo-main (doom-packages--build-dir 'foo))))))

(ert-deftest pb-test-extension-files-get-autoloads ()
  (pb-test--with-env
    (let ((pin (pb-test--commit
                "o/vx" `(,@(pb-test--lib 'vx)
                         ("extensions/vx-directory.el" .
                          ";;; vx-directory.el --- x -*- lexical-binding: t -*-\n;;;###autoload\n(defun vx-directory-enter () (interactive) nil)\n(provide 'vx-directory)\n")))))
      (setq doom-packages (list (pb-test--decl 'vx pin '(:files (:defaults "extensions/vx-*.el")))))
      (doom-packages-ensure)
      (with-temp-buffer
        (insert-file-contents (doom-packages--autoloads-file 'vx))
        (should (search-forward "(autoload 'vx-directory-enter \"vx-directory\"" nil t))
        (goto-char (point-min))
        (should (search-forward "(autoload 'vx-hello \"vx\"" nil t))))))


;;; gc

(ert-deftest pb-test-gc-removes-undeclared-repos-and-builds ()
  (pb-test--with-env
    (let ((a (pb-test--package 'a))
          (b (pb-test--package 'b)))
      (setq doom-packages (list a b))
      (doom-packages-ensure)
      (let ((old-build (expand-file-name "build-0.0/old/" (doom-packages--dir))))
        (make-directory old-build t)
        (setq doom-packages (list a))
        (doom-packages-gc)
        (should (file-directory-p (doom-packages--repos-dir "a")))
        (should (file-directory-p (doom-packages--build-dir 'a)))
        (should-not (file-exists-p (doom-packages--repos-dir "b")))
        (should-not (file-exists-p (doom-packages--build-dir 'b)))
        (should-not (file-exists-p (file-name-directory (directory-file-name old-build))))
        (should (file-directory-p (doom-packages--build-root)))
        (should-not (assq 'b (doom-packages--read-state)))
        (should (assq 'a (doom-packages--read-state)))))))


;;; Profile

(defun pb-test--generated-load-path (initial)
  "The `load-path' a session gets from the generated profile, starting from INITIAL."
  (let (forms)
    (cl-letf (((symbol-function 'doom-file-write)
               (lambda (_file contents &rest _) (setq forms contents)))
              ((get 'load-path 'initial-value) initial))
      (doom-profile--generate-init nil))
    (let ((load-path (copy-sequence initial)))
      ;; Only the `load-path' forms; the rest would touch this session's global state.
      (dolist (form (nthcdr 3 (nth 2 forms)))
        (when (and (eq (car-safe form) 'add-to-list) (equal (cadr form) ''load-path))
          (eval form t)))
      load-path)))

(ert-deftest pb-test-build-dir-precedes-emacs-lisp-dir-in-generated-load-path ()
  (pb-test--with-env
    ;; `tabulated-list' ships with Emacs; the pinned package shadows it.
    (let* ((tl (pb-test--package 'tabulated-list))
           (initial (copy-sequence load-path))
           (emacs-lib (file-name-directory (locate-library pb-test-shadowed-library)))
           (build (file-name-as-directory (doom-packages--build-dir 'tabulated-list))))
      (setq doom-packages (list tl))
      (doom-packages-ensure)
      (let* ((load-path (cons (directory-file-name build) initial))
             (generated (pb-test--generated-load-path initial)))
        (should (< (cl-position (directory-file-name build) generated :test #'file-equal-p)
                   (cl-position (directory-file-name emacs-lib) generated :test #'file-equal-p)))
        (should (equal (file-name-sans-extension (locate-library pb-test-shadowed-library nil generated))
                       (concat build pb-test-shadowed-library)))))))

(ert-deftest pb-test-package-autoloads-are-scanned-dependencies-first ()
  (pb-test--with-env
    (let ((c (pb-test--package 'c '(b)))
          (b (pb-test--package 'b '(a)))
          (a (pb-test--package 'a))
          scanned)
      (setq doom-packages (list c b a))
      (doom-packages-ensure)
      (cl-letf (((symbol-function 'doom-file-write) #'ignore)
                ((symbol-function 'doom-loaddefs-scan-literal)
                 (lambda (&rest files) (setq scanned (flatten-list files)) nil)))
        (doom-profile--generate-loaddefs-packages nil))
      (should (equal (mapcar #'file-name-nondirectory scanned)
                     '("a-autoloads.el" "b-autoloads.el" "c-autoloads.el"))))))

(provide 'packages-backend-tests)
;;; packages-backend-tests.el ends here
