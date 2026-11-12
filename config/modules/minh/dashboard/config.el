;;; minh/dashboard/config.el --- Plain startup buffer -*- lexical-binding: t; -*-

;; Self-contained: plain Elisp only, so it also loads under `emacs --batch -Q'.

(defconst m-startup-buffer-name "*startup*")

(defconst m--startup-banner
  '(" _____ "
    "| ____|  _ __ ___     __ _    ___   ___"
    "|  _|   | '_ ` _ \\   / _` |  / __| / __|"
    "| |___  | | | | | | | (_| | | (__  \\__ \\"
    "|_____| |_| |_| |_|  \\__,_|  \\___| |___/"))

(defun m--insert-centered (&rest lines)
  "Insert each of LINES centred with an :align-to display spec, then a newline."
  (dolist (line lines)
    (insert (propertize " " 'display
                        `(space :align-to (- center ,(/ (string-width line) 2))))
            line "\n")))

(defun m--package-count ()
  "Number of load-path entries added since startup (Doom's own formula)."
  (max 0 (- (length load-path) (length (get 'load-path 'initial-value)))))

(defun m--startup-banner ()
  "Insert the ASCII Emacs banner."
  (let ((longest (apply #'max (mapcar #'length m--startup-banner))))
    (dolist (line m--startup-banner)
      (m--insert-centered
       (concat line (make-string (max 0 (- longest (length line))) ?\s))))
    (insert "\n")))

(defun m--startup-calendar ()
  "Insert a clock and the current month's calendar."
  (require 'calendar)
  (insert "\n")
  (m--insert-centered
   (propertize (format-time-string "🕒 %H:%M") 'face 'font-lock-keyword-face))
  (insert "\n")
  (let* ((time (decode-time (current-time)))
         (today-day (nth 3 time))
         (month (nth 4 time))
         (year (nth 5 time))
         (days-in-month (calendar-last-day-of-month month year))
         (first-day (calendar-day-of-week (list month 1 year)))
         (padding "    ")
         (line "")
         (col 0)
         (day 1))
    (m--insert-centered
     (propertize (format "🗓️ %s %d" (calendar-month-name month) year)
                 'face 'font-lock-constant-face))
    (insert "\n")
    (m--insert-centered "Su  Mo  Tu  We  Th  Fr  Sa")
    (dotimes (_ first-day)
      (setq line (concat line padding)
            col (1+ col)))
    (while (<= day days-in-month)
      (let ((fmt (format "%3d" day)))
        (setq line (concat line
                           (if (= day today-day)
                               (propertize fmt 'face 'ansi-color-inverse)
                             fmt)
                           " ")
              col (1+ col)
              day (1+ day)))
      (when (= col 7)
        (m--insert-centered line)
        (setq line "" col 0)))
    (when (> col 0)
      (dotimes (_ (- 7 col))
        (setq line (concat line padding)))
      (m--insert-centered line))))

;; Parent nil on purpose: Doom's global hl-line only covers prog/text/conf/special/dired modes.
(define-derived-mode m-startup-mode nil "Startup"
  "Major mode of the startup buffer."
  (mode-line-invisible-mode 1)
  (hl-line-mode -1)
  (setq buffer-read-only t)
  (setq-local enable-local-variables nil))

(define-key m-startup-mode-map (kbd "q") #'quit-window)

(defun m-startup-buffer ()
  "Build (or rebuild) and return the startup buffer."
  (let ((buf (get-buffer-create m-startup-buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (m--startup-banner)
        (m--insert-centered
         (propertize (format "Loaded %d packages in %s"
                             (m--package-count) (emacs-init-time))
                     'face 'font-lock-comment-face))
        (m--startup-calendar))
      (unless (derived-mode-p 'm-startup-mode)
        (m-startup-mode))
      (goto-char (point-min)))
    buf))

(setq initial-buffer-choice #'m-startup-buffer)
