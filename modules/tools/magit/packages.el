;; -*- no-byte-compile: t; -*-
;;; tools/magit/packages.el

;; REVIEW: This file contains pinned dependencies. This goes against our policy
;;   of only pinning primary packages, but an exception is made because the
;;   Magit ecosystem seems prone to breakage.

(package! transient :built-in t) ; Emacs 31.1 ships 0.13.3; magit needs 0.13
(package! cond-let
  :recipe (:host github :repo "tarsius/cond-let")
  :pin "b992b54d3958c1f76abb05ecd6f60c645aefd647")

;; llama: dependency of magit
(package! llama
  :recipe (:host github :repo "tarsius/llama" :files ("llama.el"))
  :pin "6850d0c91b629da14fdff2300c222289d1a0029a")
;; with-editor: dependency of magit and transient
(package! with-editor
  :recipe (:host github :repo "magit/with-editor")
  :pin "254c54189e26ed9223a55cba8bbd08b51c4b83c0")
;; magit-section: dependency of magit, built from magit's repo
(package! magit-section
  :recipe (:host github :repo "magit/magit" :files ("lisp/magit-section.el"))
  :pin "5e21bac5304c931cccbe16073758e2c464e40298")

(package! magit
  :recipe (:host github :repo "magit/magit"
           :files ("lisp/magit*.el" "lisp/git-*.el" (:exclude "lisp/magit-section.el")))
  :pin "5e21bac5304c931cccbe16073758e2c464e40298")
