;;; minh/keybindings/config.el -*- lexical-binding: t; -*-

;; Centralized keybindings (all `map!' forms moved here from their
;; respective module configs and the root config.el, merged into one).

(map!
 ;; -----------------------------------------------------------------
 ;; global-map (from config.el root + modules/minh/java/config.el)
 ;; -----------------------------------------------------------------
 (:map global-map
       :n "g'mt" #'mtime/convert-selected-millis-to-date
       :n "g'mc" #'m/quick-calc-region
       :n "mhh" #'highlight-regexp
       :n "mhu" #'(lambda() (interactive) (unhighlight-regexp t))
       "C-'" #'(lambda() (interactive) (m--open-lines 1))
       "C-M-'" #'(lambda() (interactive) (m--open-lines -1))
       [C-m] #'end-of-line ; experiment 11:18:03 2024-09-08
       "C-M-v" #'(lambda() (interactive) (scroll-other-window 3))
       "M-<RET>" #'m/show-current-path
       "<f3>" nil
       "M-`" nil
       "M-h" nil
       "M-k" nil
       "M-l" nil)

 ;; -----------------------------------------------------------------
 ;; various :after maps (from config.el root)
 ;; -----------------------------------------------------------------
 (:after eshell :map evil-insert-state-map "C-r" #'consult-history) ;; experiment 09:57:23 2025-06-10
 (:after consult :n "]e" #'consult-flymake)
 (:after evil
         :n "M-K" #'(lambda() (interactive) (m--drag-line -1))
         :n "M-J" #'(lambda() (interactive) (m--drag-line 1))
         (:map evil-insert-state-map
               "C-n" #'evil-next-visual-line
               "C-p" #'evil-previous-visual-line
               "C-d" #'evil-delete-char))
 (:after corfu
         ;; revoke this feature from doom-emacs because i don't need:
         ;; https://github.com/doomemacs/doomemacs/pull/7748
         (:map corfu-mode-map
               :i "C-n" nil
               :i "C-p" nil))
 (:after evil-org
         (:map evil-org-mode-map
               :i "C-d" nil
               :n "C-c j" #'org-next-block
               :n "C-c k" #'org-previous-block
               :n "gk" (cmd! (if (org-at-heading-p) (org-backward-element) (evil-previous-visual-line)))
               :n "gj" (cmd! (if (org-at-heading-p) (org-forward-element) (evil-next-visual-line)))))
 (:after ghostel
         ;; reserve these mapping for me to switch workspace
         (:map ghostel-semi-char-mode-map
               "M-1" nil
               "M-2" nil
               "M-3" nil
               "M-4" nil
               "M-5" nil
               "M-6" nil
               "M-7" nil
               "M-8" nil
               "M-9" nil
               "M-0" nil))
 ;; magit-mode-map (from config.el root :after magit + modules/minh/gis/config.el)
 (:after magit :map magit-mode-map
         "<RET>" #'magit-diff-visit-worktree-file
         :n "C-t" nil ;; dont need switching to text mode
         :n "q" #'kill-current-buffer
         :n "I" #'m/magit-copy-current-branch)
 (:after dired
         :map dired-mode-map
         :leader
         :desc "Copy filename absolute path"
         :n "y" (cmd!
                 (let ((filename (dired-get-filename)))
                   (kill-new filename)
                   (message "Copied: %s" filename)))
         :n "C-t" nil) ;; dont need images command in dired
 (:after sh-script :map sh-base-mode-map
         "<tab>" #'(lambda() (interactive) (outline-minor-mode 1) (outline-cycle))
         :n "g'mh" #'consult-outline
         :n "<RET>" #'m/run-sh-paragraph)
 (:after ecoin
         (:map ecoin-completion-map
               "C-." #'ecoin-accept-word
               "<backtab>" #'ecoin-accept))

 ;; -----------------------------------------------------------------
 ;; leader (from config.el root + modules/minh/podel + modules/minh/gis)
 ;; -----------------------------------------------------------------
 (:leader
  :desc "Project Find my temp files" "." #'m/find-file-in-project-root
  (:prefix "m"
           :desc "Find my temp files" "x" #'m/find-in-my-tmp
           (:prefix "h"
                    :desc "Highlight symbol at point" "h" #'highlight-symbol-at-point
                    :desc "Unhighlight all" "u" #'(lambda() (interactive) (unhighlight-regexp t)))
           :desc "podman containers" "p" #'podel/list-containers
           :desc "gis status" "G" #'gis/status
           :desc "gis status" "g" #'gis/find-modified-files)
  (:prefix "s" :desc "Lookup dict.org" "t" #'dictionary-search)
  (:prefix "t"
           :desc "List project terminal" "t" #'ghostel-project-list-buffers
           :desc "List all terminals" "T" #'ghostel-list-buffers
           ;; ecoin is on everywhere via `global-ecoin-mode' -- see the root
           ;; config.el for why that is safe again.  This toggles one buffer.
           :desc "Ecoin (this buffer)" "p" #'ecoin-mode
           :desc "Switch terminal buffer" "c" #'calc)
  (:prefix "o"
           :desc "Open project dired" "o" #'project-dired)
  "<SPC>" #'m/find-file
  :desc "Consult from my useful commands" "C-r" #'m/catcmd
  :desc "Select only text in current line" "V" #'m/select-text-line)

 ;; -----------------------------------------------------------------
 ;; java (from modules/minh/java/config.el)
 ;; -----------------------------------------------------------------
 ;; `m c' is java-only, so these live here rather than in `global-map'.
 ;; `m h h' and `m h u' still work in a java buffer: Emacs merges the `m'
 ;; prefix across every active map, so a mode-local `m c' does not shadow a
 ;; global `m h' -- measured, not assumed.
 ;;
 ;; Note these six prompt for a module and never read `buffer-file-name', so
 ;; scoping them here does remove them from everywhere else they worked --
 ;; measured: text, prog, compilation and fundamental buffers all reached
 ;; `m c c' before.  Dired never did: dired's own `m' is `dired-mark', and a
 ;; major-mode binding outranks the global `m' prefix, which is also why
 ;; `m h h' does nothing in a dired buffer.  `mtm' and `mtt' below are the
 ;; two that genuinely need a java buffer.
 (:map java-ts-mode-map
       :n "mcc" #'java/compile
       :n "mcrr" #'java/rebuild-services
       :n "mcss" #'java/restart-services
       :n "mct" #'java/test
       :n "mcbl" #'java/build-lib
       :n "mcbr" #'java/build-lib-and-restart
       :n "mtm" #'java/test-current-method
       :n "mtt" #'java/test-current-class)

 ;; -----------------------------------------------------------------
 ;; eglot (from modules/minh/eglot/config.el)
 ;; -----------------------------------------------------------------
 (:after eglot
         :map eglot-mode-map :n "C-t" nil
         :n "=" #'eglot-format
         (:leader (:prefix "c" :desc "Organize imports" "o" #'eglot-code-action-organize-imports)))

 ;; -----------------------------------------------------------------
 ;; gis (from modules/minh/gis/config.el)
 ;; -----------------------------------------------------------------
 ;; On a row: stateless bindings, because vtable puts this map on every row
 ;; as a text property, which outranks the evil state maps.  `g' and `S' are
 ;; rebound because `vtable-map' would otherwise swallow them.  `q' is a no-op:
 ;; the panel stays open for its auto-fetch (`SPC w d' hides it, `SPC b k' kills it).
 (:map gis-status-vtable-map
       :desc "magit status" "<RET>" #'gis/magit-status-at-point
       "?" #'gis-dispatch
       "t" #'gis/eshell
       "b" #'gis-dispatch-branch
       "f" #'gis-dispatch-f
       "g" #'gis-dispatch-f
       "p" #'gis-dispatch-push
       "F" #'gis-dispatch-pull
       "r" #'gis-dispatch-rebase
       "I" #'gis/yank-branch-name
       "q" #'ignore
       :desc "sort column" "S" #'vtable-sort-by-current-column)
 ;; Off a row -- the column header carries vtable's own map, and point-max
 ;; carries no property at all.
 (:map gis-status-mode-map
       :n "?" #'gis-dispatch
       :n "<RET>" #'gis/magit-status-at-point
       :n "t" #'gis/eshell
       :n "b" #'gis-dispatch-branch
       :n "f" #'gis-dispatch-f
       :n "g" #'gis-dispatch-f
       :n "p" #'gis-dispatch-push
       :n "F" #'gis-dispatch-pull
       :n "r" #'gis-dispatch-rebase
       :n "I" #'gis/yank-branch-name
       :n "q" #'ignore)
 ;; `:leader' is an alias for `(:map doom-leader-map ...)' -- it always
 ;; targets that single global map, so it cannot be scoped with an outer
 ;; `:map' the way `:localleader' can.  To disable `SPC g g' inside gis
 ;; buffers alone, wrap the global command instead of trying to shadow it
 ;; per-mode.
 (:leader :desc "Magit status" "g g" #'gis/magit-status-or-status))

;; s3-manager is optional (commented out in packages.el).  Without this
;; guard the dired hook below rebinds `C' to a void command in every dired
;; buffer, and the `:map' form leaks a permanent deferred binding into
;; `map!''s pending list.  `locate-library' answers
;; "is it on the load-path" without loading it, so lazy loading is kept.
(when (locate-library "s3-manager")
  (map!
   (:leader (:prefix "m" (:prefix ("s" . "s3")
                                  :desc "Browse buckets" "3" #'s3-manager)))

   ;; `s3-manager-mode-map' binds `m' itself and registers as overriding, but a
   ;; *prefix* keymap in `global-map's Evil aux map still wins over a complete
   ;; binding in an overriding map -- measured: `m' resolved to the `m h'/`m c'
   ;; prefix and `s3-manager-mark' was unreachable.  Re-binding it here as an
   ;; Evil aux binding on the mode map outranks that.  Only `m' needs this; the
   ;; other eighteen keys in that map were checked and are fine.
   (:map s3-manager-mode-map
         :n "m" #'s3-manager-mark))

  ;; Dired's `C' cannot be bound through `dired-mode-map' above.
  ;; `evil-collection-dired' binds "C" to `dired-do-copy' in normal state, an
  ;; Evil state map outranks a major-mode map, and it initialises after this
  ;; file -- so `:map dired-mode-map :n "C"' is silently clobbered and `C'
  ;; stays `dired-do-copy', asking for a directory instead of uploading.
  ;; Measured: neither `keymap-set', nor `evil-define-key', nor
  ;; `with-eval-after-load 'evil-collection-dired' survives it.  A
  ;; buffer-local state map does, whatever the load order.
  (add-hook! 'dired-mode-hook
    (defun m/s3-dired-copy-key-h ()
      "Make `C' upload to a visible S3 listing, else plain `dired-do-copy'."
      (evil-local-set-key 'normal "C" #'s3-manager-dired-do-copy))))

;; ecim's buffers start with `*', which Doom's `doom-special-buffer-p'
;; treats as "unreal", so `next-buffer'/`previous-buffer' skip them, same
;; root cause as the gis fix above. `ecim-list-mode-hook' covers all four
;; tabulated-list views (runs/jobs/workflows/artifacts) in one hook,
;; since `provided-mode-derived-p' (which `doom-real-buffer-p' uses)
;; respects mode inheritance; `ecim-log-mode' derives from
;; `special-mode' directly, so it needs its own hook.
(when (locate-library "ecim")
  (add-hook! 'ecim-list-mode-hook #'(lambda () (setq-local doom-real-buffer-p t)))
  (add-hook! 'ecim-log-mode-hook #'(lambda () (setq-local doom-real-buffer-p t))))

;; Same root cause, for podel: its buffers ("*podel*") also start with
;; `*'.  `podel-list-mode-hook' alone covers every podel listing
;; (containers/images/ps/stats), since they all derive from it and
;; `provided-mode-derived-p' respects mode inheritance; unlike ecim,
;; podel has no separate log major mode -- logs go through plain
;; `async-shell-command', which Doom already treats as real.
(add-hook! 'podel-list-mode-hook #'(lambda () (setq-local doom-real-buffer-p t)))
