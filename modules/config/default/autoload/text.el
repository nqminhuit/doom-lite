;;; config/default/autoload/text.el -*- lexical-binding: t; -*-

;;;###autoload
(defun +default/newline-above ()
  "Insert an indented new line before the current one."
  (interactive)
  (if (and (featurep 'evil) evil-local-mode)
      (call-interactively 'evil-open-above)
    (beginning-of-line)
    (save-excursion (newline))
    (indent-according-to-mode)))

;;;###autoload
(defun +default/newline-below ()
  "Insert an indented new line after the current one."
  (interactive)
  (if (and (featurep 'evil) evil-local-mode)
      (call-interactively 'evil-open-below)
    (end-of-line)
    (newline-and-indent)))

;;;###autoload
(defun +default/yank-pop ()
  "Interactively select what text to insert from the kill ring."
  (interactive)
  (unless (fboundp 'consult-yank-pop)  ; See doomemacs/core#5013
    (error "No kill-ring search backend available. Enable vertico!"))
  (call-interactively 'consult-yank-pop))

;;;###autoload
(defun +default/yank-buffer-contents ()
  "Copy entire buffer into kill ring."
  (interactive)
  (clipboard-kill-ring-save (point-min) (point-max)))

;;;###autoload
(defun +default/yank-buffer-path (&optional root)
  "Copy the current buffer's path to the kill ring."
  (interactive)
  (if-let* ((filename (or (buffer-file-name (buffer-base-buffer))
                          (bound-and-true-p list-buffers-directory))))
      (let ((path (abbreviate-file-name
                   (if root
                       (file-relative-name filename root)
                     filename))))
        (kill-new path)
        (if (string= path (car kill-ring))
            (message "Copied path: %s" path)
          (user-error "Couldn't copy filename in current buffer")))
    (error "Couldn't find filename in current buffer")))

;;;###autoload
(defun +default/yank-path-at-point ()
  "Copy the absolute path of the file at point, or of the current buffer.
In dired, the entry at point wins; otherwise the buffer's file or directory."
  (interactive)
  (if-let* ((path (or (and (derived-mode-p 'dired-mode)
                           (dired-get-filename nil t))
                      (buffer-file-name (buffer-base-buffer))
                      (bound-and-true-p list-buffers-directory)
                      default-directory)))
      (let ((path (expand-file-name path)))
        (kill-new path)
        (message "Copied path: %s" path))
    (user-error "No path at point or in current buffer")))

;;;###autoload
(defun +default/yank-buffer-path-relative-to-project (&optional include-root)
  "Copy the current buffer's path to the kill ring.
With non-nil prefix INCLUDE-ROOT, also include the project's root."
  (interactive "P")
  (+default/yank-buffer-path
   (if include-root
       (file-name-directory (directory-file-name (doom-project-root)))
     (doom-project-root))))

;;;###autoload
(defun +default/insert-file-path (arg)
  "Insert the file name (absolute path if prefix ARG).
If `buffer-file-name' isn't set, uses `default-directory'."
  (interactive "P")
  (let ((path (or buffer-file-name default-directory)))
    (insert
     (if arg
         (abbreviate-file-name path)
       (file-name-nondirectory path)))))

;;;###autoload
(defun doom/backward-delete-whitespace-to-column ()
  "Delete back to the previous column of whitespace, or as much whitespace as
possible, or just one char if that's not possible."
  (interactive)
  (let (current-column)
    (cond
     ;; Delete up to the nearest tab column IF only whitespace between point
     ;; and bol.
     ((and (not indent-tabs-mode)
           (> tab-width 1)
           (not (bolp))
           (not (doom-point-in-string-p))
           (>= (abs (save-excursion (skip-chars-backward " \t")))
               (setq current-column (current-column))))
      (delete-char (- (1+ (% (1- current-column) tab-width)))))
     ;; Otherwise do a regular delete
     ((delete-char -1)))))

;;;###autoload
(defun +default--delete-backward-char-a (n &optional killflag)
  "Same as `delete-backward-char', but deletes back to the previous tab column
through leading whitespace (see `doom/backward-delete-whitespace-to-column').
Resorts to `delete-char' if n > 1."
  (interactive "p\nP")
  (or (integerp n)
      (signal 'wrong-type-argument (list 'integerp n)))
  (cond ((and (use-region-p)
              delete-active-region
              (= n 1))
         ;; If a region is active, kill or delete it.
         (if (eq delete-active-region 'kill)
             (kill-region (region-beginning) (region-end) 'region)
           (funcall region-extract-function 'delete-only)))
        ;; In Overwrite mode, maybe untabify while deleting
        ((null (or (null overwrite-mode)
                   (<= n 0)
                   (memq (char-before) '(?\t ?\n))
                   (eobp)
                   (eq (char-after) ?\n)))
         (let ((ocol (current-column)))
           (delete-char (- n) killflag)
           (save-excursion
             (insert-char ?\s (- ocol (current-column)) nil))))
        ;;
        ((= n 1) (doom/backward-delete-whitespace-to-column))
        ;; Otherwise, do simple deletion.
        ((delete-char (- n) killflag))))
