;;; core-trims-tests.el --- files and symbols removed by the P10 core trims -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(defconst core-trims-test--root
  (expand-file-name "../../" (file-name-directory (or load-file-name buffer-file-name))))

(load (expand-file-name "tests/config-dir.el" core-trims-test--root) nil t)

(defconst core-trims-test--deleted
  '("lisp/lib/sandbox.el" "lisp/lib/store.el" "lisp/lib/plist.el"
    "modules/doom/cli" "bin/org-capture" "bin/doom.ps1" "bin/doom.sh" "profiles"
    "bin/doom-make" "lisp/cli/make" "bin/doom-profile" "lisp/cli/autoloads.el"
    "static/init.example.el" "static/config.example.el" "static/packages.example.el"
    "lisp/lib/git.el" "modules/editor/evil/autoload/embrace.el"))

(defconst core-trims-test--compat-symbols
  '("MODULES" "NATIVECOMP" "doom-private-dir" "doom-etc-dir" "dynamic-modules"
    "jansson" "harfbuzz" "doom-dir" "doom-plist-get" "doom-unicode-font"
    "featurep!" "doom-enlist" "letenv!" "eval-if!" "eval-when!" "setq!"
    "doom-load-envvars-file" "doom-compile-functions" "appendq!" "delq!"
    "pushnew!" "prependq!" "IS-MAC" "IS-WINDOWS" "IS-BSD" "IS-LINUX" "sh!!"
    "doom/help-packages" "doom/help-modules" "doom/help-autodefs"
    "doom/help-custom-variable" "doom-profile-generators"
    "doom--system-windows-p" "doom--system-macos-p"
    "doom-git-toplevel" "doom-system-supports-symlinks-p" "doom-exec-process"
    "+default/browse-templates" "+default/find-in-templates" "doom-cli-shell"
    "+java/open-groovy-repl" "+javascript/open-repl" "doom-system-distro"
    "doom-system-distro-icon"
    "doom/homepage" "doom/report-bug" "remove-hook!" "undefadvice!"
    "unsetq-hook!" "add-load-path!" "doom-partial" "λ!" "λ!!" "with-file!"
    "sh&" "defcli-obsolete!" "defcli-stub!" "doom-cli-redirect-output"
    "doom-cli-aliases" "doom-buffers-in-mode" "doom-buried-buffer-p"
    "doom-visible-windows" "doom-mark-buffer-as-real-h" "doom-resize-window"
    "doom-recenter-a" "doom-preserve-window-position-a"
    "doom-enable-line-numbers-h" "doom-disable-show-paren-mode-h"
    "doom-point-in-string-or-comment-p"
    "doom-enable-show-trailing-whitespace-h"
    "doom-disable-show-trailing-whitespace-h" "doom-project-expand"
    "doom-font-exists-p" "doom-package-in-module-p"
    "doom-package-pinned-alist" "doom-module<-context"
    "doom-scratch-buffer-hook" "set-eglot-client!"
    "+vertico-embark-which-key-indicator" "doom-module--summary"
    "doom-module--annotate" "with-output-to!" "doom-profile->id" "section!"
    "doom-sh--pipeline-async" "doom-sh--async-sentinel"
    "doom-set-buffer-real" "doom-module--remap"
    "+default/search-notes-for-symbol-at-point" "+default/org-notes-search"
    "+default/org-notes-headlines" "+default/browse-notes"
    "+default/find-in-notes" "doom-completing-read-org-headings"
    "+evil-collection-disable-blacklist-a" "yasnippet-capf"
    "counsel-yank-pop" "helm-show-kill-ring" "counsel-rg")
  "Removed compat names; matched only in code positions, not prose or comments.")

(defconst core-trims-test--code-re
  (concat "\\(?:[('#]\\|def[a-z]+ \\)" (regexp-opt core-trims-test--compat-symbols t) "\\_>"))

(defconst core-trims-test--plain-re "doom/sandbox\\|\\_<doom-store-\\|\\_<doom-plist-")

(defconst core-trims-test--allowed '(("bin/doom-doctor" . "doom-dir"))
  "Files that legitimately use a removed name as a local variable.")

(defun core-trims-test--files ()
  (cl-loop for d in (list "lisp" "modules" (tcd-config-dir) "bin")
           append (directory-files-recursively
                   (expand-file-name d core-trims-test--root)
                   (if (equal d "bin") "\\`[^.]" "\\.el\\'"))))

(ert-deftest core-trims/deleted-files-are-gone ()
  (dolist (f core-trims-test--deleted)
    (should-not (file-exists-p (expand-file-name f core-trims-test--root)))))

(ert-deftest core-trims/no-removed-symbols ()
  (let ((case-fold-search nil) hits)
    (dolist (f (core-trims-test--files))
      (let ((rel (file-relative-name f core-trims-test--root)))
        (with-temp-buffer
          (insert-file-contents f)
          (goto-char (point-min))
          (while (not (eobp))
            (let ((line (buffer-substring (line-beginning-position) (line-end-position))))
              (unless (string-match-p "\\`[ \t]*;" line)
                (when (or (string-match core-trims-test--plain-re line)
                          (and (string-match core-trims-test--code-re line)
                               (not (equal (cdr (assoc rel core-trims-test--allowed))
                                           (match-string 1 line)))))
                  (push (cons rel line) hits))))
            (forward-line 1)))))
    (should-not hits)))

(ert-deftest core-trims/no-module-readmes ()
  (should-not (directory-files-recursively
               (expand-file-name "modules" core-trims-test--root) "\\`README\\.org\\'")))

(defconst core-trims-test--profile-names
  '("doom--noprofile" "doom-profiles-read" "doom-profiles-write-load-file"
    "doom-profiles-bootloadable-p" "doom-profile-load-file" "DOOMPROFILELOADFILE"
    "DOOMPROFILELOADPATH" "\"--profile\"")
  "Named-profile support that doom-lite removed; only the built-in profile remains.")

(ert-deftest core-trims/no-named-profile-support ()
  (let ((files (cons (expand-file-name "early-init.el" core-trims-test--root)
                     (cl-loop for d in '("lisp" "bin")
                              append (directory-files-recursively
                                      (expand-file-name d core-trims-test--root)
                                      "\\`[^.]"))))
        hits)
    (dolist (f files)
      (with-temp-buffer
        (insert-file-contents f)
        (dolist (name core-trims-test--profile-names)
          (goto-char (point-min))
          (when (search-forward name nil t)
            (push (cons (file-relative-name f core-trims-test--root) name) hits)))))
    (should-not hits)))

(defconst core-trims-test--platform-re
  "windows-nt\\|w32-\\|(featurep :system 'windows)\\|(featurep :system 'macos)")

(ert-deftest core-trims/no-windows-or-macos-branches ()
  (let ((files (cons (expand-file-name "early-init.el" core-trims-test--root)
                     (cl-loop for d in '("lisp" "bin" "modules")
                              append (directory-files-recursively
                                      (expand-file-name d core-trims-test--root)
                                      "\\`[^.]"))))
        hits)
    (dolist (f files)
      (with-temp-buffer
        (insert-file-contents f)
        (goto-char (point-min))
        (while (re-search-forward core-trims-test--platform-re nil t)
          (push (cons (file-relative-name f core-trims-test--root) (match-string 0)) hits))))
    (should-not hits)))

(defconst core-trims-test--disabled-packages
  '("groovy-mode" "android-mode" "marginalia" "nodejs-repl" "evil-lion"
    "evil-embrace" "exato" "evil-snipe" "flymake-popon")
  "Packages the user config disables; the vendored modules must not declare them.")

(ert-deftest core-trims/no-disabled-packages-declared ()
  (let (hits)
    (dolist (f (directory-files-recursively
                (expand-file-name "modules" core-trims-test--root) "\\`packages\\.el\\'"))
      (with-temp-buffer
        (insert-file-contents f)
        (dolist (name core-trims-test--disabled-packages)
          (goto-char (point-min))
          (when (re-search-forward
                 (format "(package! %s\\_>" (regexp-quote name)) nil t)
            (push (cons (file-relative-name f core-trims-test--root) name) hits)))))
    (should-not hits)))

;;; core-trims-tests.el ends here

(ert-deftest core-trims/doommodules-has-no-obsolete-list ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "modules/.doommodules" core-trims-test--root))
    (should-not (string-search "(obsolete" (buffer-string)))))
