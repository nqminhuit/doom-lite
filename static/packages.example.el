;;; $DOOMDIR/packages.el -*- lexical-binding: t; no-byte-compile: t -*-

;; To install a package:
;;
;;   1. Declare it here in a `package!' statement,
;;   2. Run 'doom sync' in the shell,
;;   3. Restart Emacs.
;;
;; Use 'C-h f package\!' to look up documentation for the `package!' macro.


;; Every package needs a `:recipe' (`:host', `:repo', optional `:files') and a
;; full-SHA `:pin'. `:host' is `github' (the default) or `codeberg'. There are
;; no recipe repos to fall back on.
;; (package! another-package
;;   :recipe (:host github :repo "username/repo")
;;   :pin "0123456789abcdef0123456789abcdef01234567")

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe'. It takes globs, `:defaults' and (:exclude ...):
;; (package! this-package
;;   :recipe (:host github :repo "username/repo"
;;            :files ("some-file.el" "src/lisp/*.el"))
;;   :pin "0123456789abcdef0123456789abcdef01234567")

;; If you'd like to disable a package included with Doom, you can do so here
;; with the `:disable' property:
;; (package! builtin-package :disable t)

;; To bump a package, edit its `:pin' and run 'doom sync'. The pin decides the
;; commit, so `:branch' is accepted but ignored.
