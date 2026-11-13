;;; emacs/vc/config.el -*- lexical-binding: t; -*-

;; Remove RCS, CVS, SCCS, SRC, and Bzr, because it's a lot less work for vc to
;; check them all (especially in TRAMP buffers), and who uses any of these in
;; 2021, amirite?
(setq-default vc-handled-backends '(SVN Git Hg))

;; PERF: Ignore node_modules (expensive for vc ops to index).
(setq-default vc-ignore-dir-regexp (format "%s\\|%s"
                                           locate-dominating-stop-dir-regexp
                                           "[/\\\\]node_modules"))

(when (featurep :system 'windows)
  (setenv "GIT_ASKPASS" "git-gui--askpass"))

;; In case the user is using `bug-reference-mode'
(map! :when (fboundp 'bug-reference-mode)
      :map bug-reference-map
      "RET" (cmds! (and (bound-and-true-p evil-mode)
                        (evil-normal-state-p))
                   #'bug-reference-push-button))

(after! log-view
  (set-evil-initial-state!
    '(log-view-mode
      vc-git-log-view-mode
      vc-hg-log-view-mode
      vc-bzr-log-view-mode
      vc-svn-log-view-mode)
    'emacs)
  (map! :map log-view-mode-map
        "j" #'log-view-msg-next
        "k" #'log-view-msg-prev))


(after! vc
  (set-popup-rules!
    '(("^\\*vc-diff" :select nil :size fit-window-to-buffer)
      ("^\\*vc-change-log" :select t))))


(after! vc-annotate
  (set-evil-initial-state! 'vc-annotate-mode 'normal)

  ;; Clean up after itself
  (define-key vc-annotate-mode-map [remap quit-window] #'kill-current-buffer))


(after! vc-dir
  (set-evil-initial-state! 'vc-dir-mode 'emacs))


(use-package! smerge-mode
  :defer t
  :init
  (add-hook! 'find-file-hook
    (defun +vc-init-smerge-mode-h ()
      (or (bound-and-true-p so-long-detected-p)
          (bound-and-true-p smerge-mode)
          (save-excursion
            (goto-char (point-min))
            (when (re-search-forward "^<<<<<<< " nil t)
              (smerge-mode 1))))))
  :config
  (map! :map smerge-mode-map
        :localleader
        "n" #'smerge-next
        "p" #'smerge-prev
        "r" #'smerge-resolve
        "a" #'smerge-keep-all
        "b" #'smerge-keep-base
        "o" #'smerge-keep-lower
        "l" #'smerge-keep-lower
        "m" #'smerge-keep-upper
        "u" #'smerge-keep-upper
        "E" #'smerge-ediff
        "C" #'smerge-combine-with-next
        "R" #'smerge-refine
        "C-m" #'smerge-keep-current
        (:prefix "="
         "<" #'smerge-diff-base-upper
         ">" #'smerge-diff-base-lower
         "=" #'smerge-diff-upper-lower)))

