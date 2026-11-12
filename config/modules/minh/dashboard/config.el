;;; minh/dashboard/config.el --- Description -*- lexical-binding: t; -*-

(require 'cl-lib)

;; Disable mode line when showing dashboard
(add-hook! +dashboard-mode #'(lambda ()
                               (mode-line-invisible-mode 1)
                               (hl-line-mode -1)))


(defun +dashboard-widget-banner ()
  "Draw a custom ASCII Emacs banner."
  (let* ((banner
          '(" _____ "
            "| ____|  _ __ ___     __ _    ___   ___"
            "|  _|   | '_ ` _ \\   / _` |  / __| / __|"
            "| |___  | | | | | | | (_| | | (__  \\__ \\"
            "|_____| |_| |_| |_|  \\__,_|  \\___| |___/"))
         (longest-line (apply #'max (mapcar #'length banner))))
    (dolist (line banner)
      (+dashboard-insert-centered
       (concat line (make-string (max 0 (- longest-line (length line))) ?\s))))
    (+dashboard-widget-spacer)
    (put-text-property (point-min) (point) 'face 'default)))

(defun m--doom-dashboard-calendar ()
  "Insert a simple time and calendar for the current month into the Doom dashboard."
  (require 'calendar)
  (insert "\n")
  ;; Clock line at the top
  (let ((clock-str (format-time-string "🕒 %H:%M")))
    (+dashboard-insert-centered (propertize clock-str 'face 'font-lock-keyword-face))
    (+dashboard-widget-spacer))
  (let* ((time (decode-time (current-time)))
         (today-day (nth 3 time))
         (today-month (nth 4 time))
         (today-year (nth 5 time))
         (month today-month)
         (year today-year)
         (month-name (calendar-month-name month))
         (days-in-month (calendar-last-day-of-month month year))
         (first-day (calendar-day-of-week (list month 1 year))))
    ;; Header
    (+dashboard-insert-centered
     (propertize (format "🗓️ %s %d" month-name year)
                 'face 'font-lock-constant-face))
    (+dashboard-widget-spacer)

    ;; Weekdays
    (+dashboard-insert-centered "Su  Mo  Tu  We  Th  Fr  Sa")
    ;; Day rendering
    (let ((col 0)
          (line "")
          (day 1)
          (padding "    ")) ;; padding = format-day + day-spacing
      ;; Fill initial blanks
      (dotimes (_ first-day)
        (setq line (concat line padding))
        (setq col (1+ col)))
      ;; Fill day numbers
      (while (<= day days-in-month)
        (let* ((highlight (and (= day today-day)
                               (= month today-month)
                               (= year today-year)))
               (fmt (format "%3d" day)) ;; format-day
               (cell (if highlight
                         (propertize fmt 'face 'ansi-color-inverse)
                       fmt)))
          (setq line (concat line cell " ")) ;; day-spacing
          (setq col (1+ col))
          (setq day (1+ day)))
        (when (= col 7)
          (+dashboard-insert-centered line)
          (setq line "")
          (setq col 0)))
      ;; Final padding if last row incomplete
      (when (> col 0)
        (dotimes (_ (- 7 col))
          (setq line (concat line padding)))
        (+dashboard-insert-centered line)))))


(setopt +dashboard-functions '(+dashboard-widget-banner
                               +dashboard-widget-loaded
                               m--doom-dashboard-calendar))
