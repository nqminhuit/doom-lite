;;; config/default/autoload/search.el -*- lexical-binding: t; -*-

;;;###autoload
(defun +default/search-cwd (&optional arg)
  "Conduct a text search in files under the current folder.
If prefix ARG is set, prompt for a directory to search from."
  (interactive "P")
  (dlet ((default-directory
          (if arg
              (read-directory-name "Search directory: ")
            default-directory)))
    (call-interactively #'+vertico/project-search-from-cwd)))

;;;###autoload
(defun +default/search-other-cwd ()
  "Conduct a text search in another directory."
  (interactive)
  (+default/search-cwd 'other))

;;;###autoload
(defun +default/search-emacsd ()
  "Conduct a text search in files under `doom-emacs-dir'."
  (interactive)
  (dlet ((default-directory doom-emacs-dir))
    (call-interactively #'+vertico/project-search-from-cwd)))

;;;###autoload
(defun +default/search-buffer ()
  "Conduct a text search on the current buffer.

If a selection is active and multi-line, perform a search restricted to that
region.

If a selection is active and not multi-line, use the selection as the initial
input and search the whole buffer for it."
  (interactive)
  (let (start end multiline-p)
    (save-restriction
      (when (region-active-p)
        (setq start (region-beginning)
              end   (region-end)
              multiline-p (/= (line-number-at-pos start)
                              (line-number-at-pos end)))
        (deactivate-mark)
        (when multiline-p
          (narrow-to-region start end)))
      (if (and start end (not multiline-p))
          (consult-line
           (replace-regexp-in-string
            " " "\\\\ "
            (regexp-quote
             (buffer-substring-no-properties start end))))
        (call-interactively #'consult-line)))))

;;;###autoload
(defun +default/search-project (&optional arg)
  "Conduct a text search in the current project root.
If prefix ARG is set, include ignored/hidden files."
  (interactive "P")
  (let* ((disabled-command-function nil)
         (current-prefix-arg (unless (eq arg 'other) arg))
         (default-directory
           (if (eq arg 'other)
               (if-let* ((projects (project-known-project-roots)))
                   (completing-read "Search project: " projects nil t)
                 (user-error "There are no known projects"))
             default-directory)))
    (call-interactively #'+vertico/project-search)))

;;;###autoload
(defun +default/search-other-project ()
  "Conduct a text search in a known project."
  (interactive)
  (+default/search-project 'other))

;;;###autoload
(defun +default/search-project-for-symbol-at-point (symbol dir)
  "Search current project for symbol at point.
If prefix ARG is set, prompt for a known project to search from."
  (interactive
   (list (or (doom-thing-at-point-or-region) "")
         (if current-prefix-arg
             (if-let* ((projects (project-known-project-roots)))
                 (completing-read "Search project: " projects nil t)
               (user-error "There are no known projects"))
           (doom-project-root default-directory))))
  (+vertico/project-search nil symbol dir))
