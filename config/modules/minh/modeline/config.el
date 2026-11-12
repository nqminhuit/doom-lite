;;; minh/modeline/config.el --- Description -*- lexical-binding: t; -*-

;; this config is base on Protesilaos' tutorial:
;; config: https://protesilaos.com/codelog/2023-07-29-emacs-custom-modeline-tutorial/

;;; modeline flymake

(defun prot-modeline--flymake-segment ()
  "Return the Flymake diagnostic counters as a mode line string.

Counts every severity in a single pass over `flymake-diagnostics'.  The
previous implementation called a per-type counter three times, and each
call collected *all* diagnostics in the buffer before filtering -- three
full scans of every diagnostic on every redisplay of the selected
window."
  (let ((error-sev (flymake--severity :error))
        (warning-sev (flymake--severity :warning))
        (note-sev (flymake--severity :note))
        (errors 0) (warnings 0) (notes 0))
    (dolist (d (flymake-diagnostics))
      (let ((sev (flymake--severity (flymake-diagnostic-type d))))
        (cond ((= sev error-sev) (cl-incf errors))
              ((= sev warning-sev) (cl-incf warnings))
              ((= sev note-sev) (cl-incf notes)))))
    ;; `concat' treats nil as the empty sequence, so absent counters just
    ;; drop out -- matching the old " []" when nothing is reported.
    (concat " ["
            (unless (zerop errors)
              (propertize (number-to-string errors) 'face 'error))
            (unless (zerop warnings)
              (concat " " (propertize (number-to-string warnings) 'face 'warning)))
            (unless (zerop notes)
              (concat " " (propertize (number-to-string notes) 'face 'success)))
            "]")))

(defvar-local prot-modeline-flymake
    '(:eval
      (when (and (bound-and-true-p flymake-mode)
                 (mode-line-window-selected-p))
        (prot-modeline--flymake-segment)))
  "Mode line construct displaying `flymake-mode-line-format'.
Specific to the current window's mode line.")

;;; caches (computed on demand / on file events, never on every redraw)
;;
;; Everything the mode line needs that touches the filesystem is cached
;; buffer-locally and stored *display-ready* (already propertized), because
;; `mode-line-format' is evaluated once per window on every redisplay.

(defvar-local prot-modeline--branch nil
  "Cached, display-ready VC branch segment for the current buffer.
Nil when the buffer visits no version-controlled local file.")

(defun prot-modeline--update-branch ()
  (setq prot-modeline--branch
        (when-let* ((file (buffer-file-name))
                    ((not (file-remote-p file)))
                    (backend (vc-backend file))
                    (rev (ignore-errors
                           (or (and (eq backend 'Git) (vc-git--symbolic-ref file))
                               (let ((rev (vc-working-revision file backend)))
                                 (and rev (substring rev 0 7)))))))
          (concat "🌿" (propertize rev 'face 'shadow)))))

(defvar-local prot-modeline--project nil
  "Cache of the project-root segment, as ((DIRECTORY . BUFFER-NAME) . DISPLAY).
Keyed so buffers that move (eshell, dired) or get renamed recompute,
while ordinary buffers only ever compute once.")

(defun prot-modeline--update-project ()
  "Invalidate the cached project-root segment for this buffer."
  (setq prot-modeline--project nil))

(defun prot-modeline--project-root ()
  "Return the display-ready project-root segment for this buffer.
`m--truncate-my-project-path' walks the filesystem with
`locate-dominating-file' (~0.5-1.2ms), so it must never run from
redisplay directly."
  ;; Keyed on the buffer name as well as the directory: when no project
  ;; marker is found `m--truncate-my-project-path' falls back to the buffer
  ;; name, and that fallback gets cached too -- so a `rename-buffer' would
  ;; otherwise show the stale name forever.
  (let ((key (cons default-directory (buffer-name))))
    (if (equal key (car prot-modeline--project))
        (cdr prot-modeline--project)
      (cdr (setq prot-modeline--project
                 (cons key
                       (propertize
                        ;; Never stat a remote path from redisplay.
                        (or (file-remote-p default-directory 'host)
                            (m--truncate-my-project-path))
                        'face 'dired-directory)))))))

(dolist (hook '(find-file-hook after-save-hook after-revert-hook))
  (add-hook hook #'prot-modeline--update-branch)
  (add-hook hook #'prot-modeline--update-project))
(with-eval-after-load 'magit
  ;; Also drops the project cache: `m--truncate-my-project-path' caches its
  ;; `(buffer-name)' fallback when no marker was found, so a repo created
  ;; after the buffer was opened would never show up otherwise.
  (add-hook 'magit-post-refresh-hook #'prot-modeline--update-branch)
  (add-hook 'magit-post-refresh-hook #'prot-modeline--update-project))

;;; default global configs
(setq-default mode-line-format
              (list
               "%e"
               '(:eval
                 (let ((file (buffer-file-name)))
                   (concat
                    "📁" (prot-modeline--project-root)
                    "📄" (propertize (if file
                                         (file-name-nondirectory file)
                                       (buffer-name))
                                     'face '(:weight bold))
                    " "
                    (and file (buffer-modified-p) "✱")
                    (and buffer-read-only "🔒")
                    prot-modeline--branch
                    " ")))
               '(:eval (when defining-kbd-macro (propertize "<F4>" 'face 'highlight)))
               "%l:%c "
               '(:eval (when (mode-line-window-selected-p) "%p "))
               " "
               '(:eval (when (mode-line-window-selected-p) mode-name))
               prot-modeline-flymake))
