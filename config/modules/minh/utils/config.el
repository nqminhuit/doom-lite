;;; minh/utils/config.el -*- lexical-binding: t; -*-

;; Definitions that must exist eagerly live here rather than in
;; autoload.el.  Doom only harvests `;;;###autoload' cookies from
;; autoload.el and loads the file lazily, so a bare `advice-add' or a
;; command bound from the root config.el would not take effect until
;; some *other* autoloaded function in that file happened to run.

(with-eval-after-load 'evil
  ;; Bound to `c' in normal and visual state from the root config.el, so
  ;; this cannot be lazy: it has to exist as soon as evil does.
  (evil-define-operator evil-change-without-register
    (beg end type yank-handler delete-func)
    "Change text from BEG to END with TYPE.
Do not save in REGISTER nor the kill-ring with YANK-HANDLER.
DELETE-FUNC is a function for deleting text, default `evil-delete'.
If TYPE is `line', insertion starts on an empty line.
If TYPE is `block', the inserted text in inserted at each line
of the block."
    (interactive "<R><x><y>")
    (evil-change beg end type ?_ yank-handler delete-func))

  (defun m/evil-write-prevent-quote (args)
    "Prevent saving to new file name `\'' with `:w\''."
    (if (equal "'" (nth 3 args))
        (remove "'" args)
      args))

  (advice-add #'evil-write :filter-args #'m/evil-write-prevent-quote))
