;;; editor/evil/autoload/comment.el -*- lexical-binding: t; -*-

;;;###autoload (autoload '+evil:comment "editor/evil/autoload/comment" nil t)
(evil-define-operator +evil:comment (beg end type)
  "Comment or uncomment the text covered by the motion."
  :move-point nil
  (interactive "<R>")
  (cond ((eq type 'block)
         (evil-apply-on-block #'comment-or-uncomment-region beg end nil))
        (t (comment-or-uncomment-region beg end)))
  (when (eq type 'line)
    (goto-char beg)
    (back-to-indentation)))
