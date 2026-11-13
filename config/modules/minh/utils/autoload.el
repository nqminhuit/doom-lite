;;; minh/minh-utils/autoload.el -*- lexical-binding: t; -*-

(defcustom m-fd-ignore-file "/opt/minh/linux-config/configs/dotfiles/terminal/.m-ignore"
  "Path to the fd ignore file used by `m/find-file`.
Customize this to point to a project-specific ignore file if needed."
  :type 'file
  :group 'minh)

(defun m--fd-args ()
  "Return the `fd' argument list used by `m/find-file'.
Built on demand rather than as a `defconst': the old constant baked in
`m-fd-ignore-file' at load time, so customising the defcustom it reads
had no effect."
  (list "-HI" "-c" "never" "--type" "f"
        "--ignore-file" (expand-file-name m-fd-ignore-file)))

(defun m--call (program &rest args)
  "Run PROGRAM with ARGS and return its stdout as a string.
Deliberately not `shell-command-to-string': that spawns `shell-file-name'
-c, and a `~/.zshenv' that sources nvm/sdkman costs ~400ms per spawn --
measured 421ms for the `fd' call below, of which fd itself was 5ms.
Stderr stays out of the result -- fd reports a bad ignore file on stderr
and still exits 0 -- so it is shown as a message; a non-zero exit signals."
  (let ((stderr-file (make-temp-file "m-call")))
    (unwind-protect
        (with-temp-buffer
          (let ((status (apply #'process-file program nil (list t stderr-file) nil args))
                (stderr (with-temp-buffer
                          (insert-file-contents stderr-file)
                          (string-trim (buffer-string)))))
            (unless (eql status 0)
              (error "%s exited with %s: %s" program status stderr))
            (unless (string-empty-p stderr)
              (message "%s: %s" program stderr))
            (buffer-string)))
      (delete-file stderr-file))))

(defconst my-tmp-dir "/tmp/minh/")

(defun m--get-parent-dir-only (mdir)
  (file-name-nondirectory (directory-file-name (file-name-directory mdir))))

;;;###autoload
(defun mtime/insert-current-millis ()
  "Insert the current time as milliseconds since the Unix epoch at point.
Also copies the value to the kill ring and displays a message with the copied value."
  (interactive)
  (let ((millis (format-time-string "%s%3N" (current-time))))
    (insert millis)
    (kill-new millis)
    (message "Copied: '%s'" millis)))

;;;###autoload
(defun mtime/convert-millis-to-date (millis)
  "Convert a Unix timestamp in milliseconds (as a string) to a human-readable date.
The output format is `%H:%M:%S %Y-%m-%d`.  Copies the result to the kill ring
and displays a message with the copied value.

Argument MILLIS: A string representing the timestamp in milliseconds (e.g., \"1729170000123\")."
  (interactive "sTimestamp millis:")
  (let* ((ms (if (stringp millis)
                 (string-to-number millis)
               (user-error "Timestamp must be a string representing milliseconds")))
         (seconds (floor (/ ms 1000.0)))
         (time (format-time-string "%H:%M:%S %Y-%m-%d" (seconds-to-time seconds))))
    (kill-new time)
    (message "Copied: '%s'" time)))

;;;###autoload
(defun mtime/convert-selected-millis-to-date ()
  "Convert the milliseconds timestamp at point to a human-readable date.
Uses the word at point as the timestamp input.
See `mtime/convert-millis-to-date'
for details on the conversion and output format."
  (interactive)
  (mtime/convert-millis-to-date
   (or (word-at-point) (user-error "No word at point"))))

;;;###autoload
(defun m/catcmd ()
  "Copy a useful Linux command from a predefined reference file to the kill ring.
Uses `consult' to select from the commands listed in
`/opt/minh/linux-config/ref/useful_linux_commands'.
Strips trailing `$` if present and displays
a message with the copied command."
  (interactive)
  (require 'consult)
  (let* ((file "/opt/minh/linux-config/ref/useful_linux_commands")
         (lines (with-temp-buffer
                  (insert-file-contents file)
                  (split-string (buffer-string) "\n" t)))
         (str-cmd (consult--read lines))
         (cmd (string-trim (replace-regexp-in-string "^\\(.*?\\)\\$" "" str-cmd))))
    (kill-new cmd)
    (message "Copied: %s" cmd)))

(defun m/uuid ()
  (let ((uuidcmd (cl-find-if #'executable-find (list "uuidgen" "dbus-uuidgen"))))
    (unless uuidcmd
      (user-error "No uuid generator found (install uuidgen or dbus-uuidgen)"))
    (string-trim (m--call uuidcmd))))

;;;###autoload
(defun m/kill-and-insert-uuid ()
  (interactive)
  (let ((uuid (m/uuid)))
    (kill-new uuid)
    (insert uuid)))

;;;###autoload
(defun m--truncate-my-project-path ()
  "Return the truncated project root based on known markers.
Searches for `go.mod`, `pom.xml`, or `.git` upward from `default-directory`.
Falls back to `buffer-name` if nothing is found."
  (let ((markers '("pom.xml" "go.mod" ".git")))
    (or (cl-loop for marker in markers
                 for path = (locate-dominating-file default-directory marker)
                 for result = (and path
                                   (file-name-nondirectory
                                    (directory-file-name path)))
                 when result return result)
        (buffer-name))))

(defun m--align-separate (left right width)
  "Return a string concated by LEFT and RIGHT.
While LEFT will be left aligned, and RIGHT will be right aligned within
WIDTH columns.  WIDTH is passed in rather than read from `window-width'
so callers can hoist it out of a loop over thousands of candidates."
  ;; Pad by `string-width', not `length': the column budget is display
  ;; columns, and CJK/emoji characters occupy two each.
  (concat left " "
          (make-string (max 0 (- width (string-width left) 2 (string-width right))) ?\s)
          right))

(defun m--completion-column-width ()
  "Column width to align completion candidates in."
  (let ((win-width (window-width)))
    (if (>= win-width 200) (/ win-width 2) win-width)))

;;;###autoload
(defun mm--get-file-names (lst proj)
  "Build an alist of (DISPLAY . PATH) from the file paths in LST.
DISPLAY is the base name with the directory -- relative to PROJ --
right-aligned in a shadowed column.

The relative directory is derived by slicing PROJ off the front of each
path instead of calling `file-relative-name', which otherwise accounts
for ~75% of this function's runtime (252ms of 335ms over 20k paths).
Paths that do not live under PROJ fall back to `file-relative-name'."
  (let* ((width (m--completion-column-width))
         (prefix (and proj (not (string-empty-p proj)) (file-name-as-directory proj)))
         (plen (length prefix))
         cand)
    (dolist (i lst (nreverse cand))
      (let* ((cut (1+ (or (cl-position ?/ i :from-end t) -1)))
             (base (if (zerop cut) i (substring i cut)))
             (dir (cond
                   ((or (null proj) (zerop cut)) nil)
                   ;; Fast path: absolute path under PROJ, just slice.
                   ((and prefix (string-prefix-p prefix i))
                    (if (= cut plen) "./" (substring i plen cut)))
                   ;; Relative paths, or siblings of PROJ needing "../".
                   (t (file-relative-name (substring i 0 cut) proj)))))
        (push (cons (if dir
                        (m--align-separate
                         base (propertize dir 'face 'font-lock-comment-face) width)
                      base)
                    i)
              cand)))))

;;;###autoload
(defun m/find-file ()
  "Find and open a file in the current project using `fd` and `consult'."
  (interactive)
  (require 'consult)
  (unless (executable-find "fd")
    (user-error "`fd' not found in `exec-path' -- run `doom env'"))
  (let* ((project (project-current))
         (proj (or (and project (project-root project))
                   (user-error "Not in a project")))
         (candidates (split-string
                      (apply #'m--call "fd" (append (m--fd-args) (list "." proj)))
                      "\n" t))
         ;; alist: (("display" . "realpath") ...).  `assoc' here is O(n) but
         ;; runs once per invocation -- a hash table costs more to build
         ;; (4.7ms at 20k candidates) than the single lookup it saves.
         (resolved-cand (mm--get-file-names candidates proj)))
    (unless resolved-cand
      (user-error "No matching files found via fd in project"))
    (when-let ((selected (consult--read resolved-cand
                                        :lookup (lambda (sel &rest _) (cdr (assoc sel resolved-cand)))
                                        ;; :initial "!test "
                                        :prompt "Find file: ")))
      (find-file selected)))
  (setq this-command 'find-file))

;;;###autoload
(defun m/dict (word)
  (interactive
   ;; `word-at-point' is nil off a word; `downcase' would signal there.
   (let ((wrd (downcase (or (word-at-point) ""))))
     (list
      (read-string
       (format "Search word (default: '%s'): " wrd) nil nil wrd))))
  (require 'eww)
  (eww-browse-with-external-browser
   (format "https://www.oxfordlearnersdictionaries.com/definition/english/%s?q=%s" word word)))

;;;###autoload
(defun m/show-current-path ()
  (interactive)
  (if-let (filename (buffer-file-name (buffer-base-buffer)))
      (let ((path (abbreviate-file-name filename)))
        (message "%s" path))))

;;;###autoload
(defun m/empty-kill-ring ()
  (interactive)
  (setq kill-ring nil))

(defun m--drag-1-line (n)
  "Drag the current line up or down by N lines.
Preserve visual column even with tabs or shorter lines."
  (let* ((col (current-column))
         (start (line-beginning-position))
         (end (min (point-max) (1+ (line-end-position))))
         (line-text (buffer-substring start end)))
    (delete-region start end)
    (forward-line n)
    (let ((insert-point (point)))
      (insert line-text)
      (goto-char insert-point)
      (move-to-column col t))))  ; ← t pads with spaces if needed

(defun m--drag-line (n)
  "Drag the current line up or down by N lines."
  (if mark-active
      nil
    (m--drag-1-line n)))

(defun m--open-lines (n)
  "Like `open-line' but does not enforce pointer position.
If N is negative, insert N lines above."
  (when (not (= n 0))
    (save-excursion
      (if (> n 0)
          (progn
            (end-of-line)
            (open-line 1))
        (progn
          (beginning-of-line)
          (forward-char -1)
          (insert (if use-hard-newlines hard-newline "\n")))))))

;;;###autoload
(defun m/run-sh-paragraph ()
  "Run the current shell block defined by `###` headers via `compile`.
If a `### vars` or `### globals` block exists earlier in the buffer, its
contents will be prepended so common shell variables (e.g., token=...) can be centralized."
  (interactive)
  (save-excursion
    (unless (re-search-backward "^###" nil t)
      (user-error "No '###' start header found"))
    ;; mark the current subtree and capture its text
    (outline-mark-subtree)
    (let* ((region-text (buffer-substring-no-properties (region-beginning) (region-end)))
           (vars-text (save-excursion
                        (goto-char (point-min))
                        (when (re-search-forward "^###\\s-*\\(?:vars\\|globals\\)\\b" nil t)
                          (let ((vars-start (progn (goto-char (match-end 0)) (forward-line 1) (point)))
                                vars-end)
                            (save-excursion
                              (goto-char vars-start)
                              (if (re-search-forward "^###" nil t)
                                  (setq vars-end (match-beginning 0))
                                (setq vars-end (point-max))))
                            (buffer-substring-no-properties vars-start vars-end))))))
      (if (and vars-text (not (string-match-p "\\`[ \t\n\r]*\\'" vars-text)))
          (compile (concat vars-text "\n" region-text))
        (compile region-text))
      (deactivate-mark))))

;;;###autoload
(defun prot-common-crm-exclude-selected-p (input)
  "Filter out INPUT from `completing-read-multiple'.
Hide non-destructively the selected entries from the completion
table, thus avoiding the risk of inputting the same match twice.

To be used as the PREDICATE of `completing-read-multiple'.
Source: https://github.com/protesilaos/dotfiles/blob/master/emacs/.emacs.d/prot-emacs.org"
  (if-let* ((pos (string-match-p crm-separator input))
            (rev-input (reverse input))
            (element (reverse
                      (substring rev-input 0
                                 (string-match-p crm-separator rev-input))))
            (flag t))
      (progn
        (while pos
          (if (string= (substring input 0 pos) element)
              (setq pos nil)
            (setq input (substring input (1+ pos))
                  pos (string-match-p crm-separator input)
                  flag (when pos t))))
        (not flag))
    t))

;;;###autoload
(defun m/select-text-line ()
  "Select only text in current line."
  (interactive)
  (back-to-indentation)
  (push-mark (line-end-position) nil t))

;;;###autoload
(defun m/find-in-my-tmp ()
  "Find file under `my-tmp-dir' directory."
  (interactive)
  (make-directory my-tmp-dir t)
  (let* ((default-directory my-tmp-dir)
         (file (read-file-name "Find temp file: ")))
    (when (and file (not (string-empty-p file)))
      (split-window-below)
      (other-window 1)
      (find-file file)
      (setq this-command 'find-file))))

;;;###autoload
(defun m/find-file-in-project-root ()
  "Find file under project root directory."
  (interactive)
  (let ((default-directory (project-root (project-current t))))
    (call-interactively 'find-file))
  (setq this-command 'find-file))

;;;###autoload
(defun m/magit-copy-current-branch ()
  "Show the current branch in the echo-area and add it to the `kill-ring'."
  (interactive)
  (let ((branch (magit-get-current-branch)))
    (if branch
        (progn (kill-new branch)
               (message "'%s' copied" branch))
      (user-error "There is no current git branch"))))

;;;###autoload
(defun m/quick-calc-region (beg end)
  "Evaluate math expression in region or current line and insert result right after it.
If an existing = result is present at the end of the region, automatically remove it before evaluating."
  (interactive
   (list
    (if (use-region-p)
        (region-beginning)
      (line-beginning-position))
    (if (use-region-p)
        (region-end)
      (line-end-position))))
  (require 'calc)
  (require 'calc-ext)
  (require 'subr-x)
  (let* ((orig (buffer-substring-no-properties beg end))
         ;; Find an existing "=" (optionally surrounded by space) and trim it away
         (eq-pos (string-match "\\s-*=" orig))
         (expr (if eq-pos
                   (string-trim-right (substring orig 0 eq-pos))
                 (string-trim orig))))
    ;; If there was an existing "= result" appended, remove it from buffer
    (when eq-pos
      (let ((del-start (+ beg eq-pos)))
        (delete-region del-start end)
        (setq end del-start)))
    (unless (and expr (not (string= expr "")))
      (user-error "No expression to evaluate"))
    (let ((result (calc-eval expr)))
      (save-excursion
        (goto-char end)
        (insert " = " result)))))
