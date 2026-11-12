;;; minh/gis/autoload.el -*- lexical-binding: t; -*-

(require 'ansi-color)
(require 'cl-lib)
;; `string-trim' and friends were already being used on the assumption that
;; something else had pulled these in.
(require 'subr-x)
(require 'vtable)

;; Defined in config.el, which Doom loads eagerly, and filled in by the
;; keybindings module.
(defvar gis-status-vtable-map)

(defconst gis-mode-name "gis-mode"
  "Mode line lighter for `gis-status-mode'.")

(define-derived-mode gis-status-mode special-mode gis-mode-name)

(defgroup gis nil
  "Drive the gis CLI over several git repositories at once."
  :group 'tools
  :prefix "gis-")

;; The status document carries no colors -- the CLI colors its *text* output
;; from these same two settings in ~/.config/gis.config, so the table has to
;; know them to keep the branch colors meaning the same thing.
(defcustom gis-default-branches '("master" "main" "develop")
  "Branch names to display as a module's default branch.
Mirrors the `default_branches' key of ~/.config/gis.config."
  :type '(repeat string))

(defcustom gis-feature-branch-prefixes '("feature/")
  "Prefixes marking a branch as a feature branch.
Mirrors the `feature_branch_prefixes' key of ~/.config/gis.config."
  :type '(repeat string))

(defcustom gis-auto-fetch-interval 300
  "Seconds between automatic `gis fetch' runs in an open status buffer.
Nil disables the automatic fetch."
  :type '(choice (const :tag "Disabled" nil) integer))

(defface gis-root-module '((t :inherit bold))
  "Face for the name of the root module.")
(defface gis-default-branch '((t :inherit error))
  "Face for a branch listed in `gis-default-branches'.")
(defface gis-feature-branch '((t :inherit warning))
  "Face for a branch matching `gis-feature-branch-prefixes'.")
(defface gis-other-branch '((t :inherit success))
  "Face for any other branch.")
(defface gis-detached '((t :inherit warning))
  "Face for a module whose HEAD is detached.")
(defface gis-ahead '((t :inherit success))
  "Face for the number of commits a module is ahead of its upstream.")
(defface gis-behind '((t :inherit error))
  "Face for the number of commits a module is behind its upstream.")
(defface gis-staged '((t :inherit success))
  "Face for the count of staged files.")
(defface gis-unstaged '((t :inherit error))
  "Face for the count of unstaged files.")
(defface gis-dim '((t :inherit shadow))
  "Face for what needs no attention: nothing tracked, nothing to commit.")
(defface gis-progress-running '((t :inherit warning))
  "Face for a module a gis command is working on.")
(defface gis-progress-done '((t :inherit success))
  "Face for a module a gis command has finished with.")
(defface gis-progress-failed '((t :inherit error))
  "Face for a module a gis command failed on.")
(defface gis-table '((t :inherit default))
  "Face for the status table.
Overrides vtable's own default face, which inherits `variable-pitch'.")

(defcustom gis-config-file
  (expand-file-name "gis.config" (or (getenv "XDG_CONFIG_HOME") "~/.config"))
  "The gis CLI's own config file, read to keep the branch colors in sync."
  :type 'file)

(defvar gis--config-cache nil
  "Cons of `gis-config-file's modification time and its parsed alist.")

(defun gis--parse-config (file)
  "Parse FILE, a java properties file, into an alist of key to value list."
  (with-temp-buffer
    (insert-file-contents file)
    (let (alist)
      (while (re-search-forward "^\\([^#=\n]+\\)=\\(.*\\)$" nil t)
        (push (cons (string-trim (match-string 1))
                    (split-string (match-string 2) "," t "[ \t]+"))
              alist))
      alist)))

(defun gis--config (key fallback)
  "Value of KEY in `gis-config-file' as a list, FALLBACK when it has no such key.
A key present in the file *replaces* the fallback rather than adding to
it, which is how GisConfig.java reads this very same file -- so the table
colors branches exactly like the CLI does."
  (let ((mtime (file-attribute-modification-time (file-attributes gis-config-file))))
    (when (and mtime (not (equal mtime (car gis--config-cache))))
      (setq gis--config-cache (cons mtime (gis--parse-config gis-config-file))))
    (if-let* ((entry (assoc key (cdr gis--config-cache))))
        (cdr entry)
      fallback)))

;;;###autodef
(defun gis--get-gis-marker()
  "Check if current directory belong to a git submodule or gis modules.
Return the root module."
  (unless (executable-find "gis") (user-error "Couldn't find 'gis' in your PATH"))
  ;; Expanded because status buffers are keyed on this string.
  (expand-file-name
   (or (locate-dominating-file default-directory ".gis-modules" )
       (locate-dominating-file default-directory ".gitmodules")
       (user-error "Buffer does not belong to a git submodule!"))))

(defun gis--parse-modules ()
  "Parse module names from .gis-modules or .gitmodules in default-directory.
Prefer .gis-modules over .gitmodules. Signal error if neither exists."
  (cond
   ((file-exists-p ".gis-modules")
    (with-temp-buffer
      (insert-file-contents ".gis-modules")
      (let (modules)
        (while (re-search-forward "^path = \\(.+\\)$" nil t)
          (push (match-string 1) modules))
        (nreverse modules))))
   ((file-exists-p ".gitmodules")
    (with-temp-buffer
      (insert-file-contents ".gitmodules")
      (let (modules)
        (while (re-search-forward "^[\t ]+path = \\(.+\\)$" nil t)
          (push (match-string 1) modules))
        (nreverse modules))))
   (t (user-error "No .gis-modules or .gitmodules found in project root"))))

(defconst gis-program "gis")

;;; Running gis
;;
;; The status buffer used to be filled by `shell-command-to-string', which
;; blocks all of Emacs.  `gis st' shells out to git once per submodule, so
;; on a repo with many modules that is a visible freeze -- and the refresh
;; keys (`f'/`g', and the sentinel in `gis--call-gis-function') run the
;; same command, so every refresh froze the editor again.
;;
;; Commands that feed a completion prompt stay synchronous on purpose: the
;; prompt cannot open until its candidates exist, so there is nothing to
;; overlap with.  They do go through `process-lines' rather than a shell,
;; which avoids quoting the arguments and surfaces a failing gis as an
;; error instead of prompting with its stderr as the candidate list.

(defvar-local gis--process nil
  "The gis process currently populating this buffer, if any.")

(defvar-local gis--root nil
  "Absolute gis root this status buffer reports on.")

(defvar-local gis--command-process nil
  "The fetch, pull or push running for this buffer, if any.
Separate from `gis--process' so a status refresh and a command cannot
cancel each other.")

(defvar-local gis--command-label nil
  "What that command is doing.")

(defvar-local gis--command-log nil
  "Its stderr lines that were not progress snapshots.")

(defvar-local gis--progress nil
  "Newest `--progress' snapshot: an alist of module name to state.
Outlives the command, so its markers stay on the rows until the next one
or a manual refresh.")

(defvar-local gis--fetch-timer nil
  "Timer that periodically runs `gis fetch' in this status buffer, if any.")

;; Survive the `kill-all-local-variables' done by `gis-status-mode'.
(dolist (symbol '(gis--process gis--root gis--command-process
                  gis--command-label gis--command-log gis--progress
                  gis--fetch-timer))
  (put symbol 'permanent-local t))

(defun gis--discard-buffer (buffer)
  "Kill BUFFER, first deleting whatever process still holds it.
The stderr pipe is a process of its own, and killing a buffer that a live
process is attached to prompts."
  (when (buffer-live-p buffer)
    (when-let* ((proc (get-buffer-process buffer)))
      (delete-process proc))
    (kill-buffer buffer)))

(defun gis--run (args callback)
  "Run `gis-program' with ARGS asynchronously for the current buffer.
CALLBACK is called in that buffer with stdout, stderr and the exit
status.  Cancels any run still in flight, so holding down the refresh key
cannot pile up processes.

The two streams are kept apart because the status output is JSON: gis
writes a warning per troubled module to stderr, which would otherwise be
spliced into the middle of the document and make it unparsable."
  (let ((buf (current-buffer)))
    (when (process-live-p gis--process)
      (set-process-sentinel
       gis--process
       (lambda (proc _event)
         (unless (process-live-p proc)
           (gis--discard-buffer (process-buffer proc))
           (gis--discard-buffer (process-get proc 'gis-stderr)))))
      (delete-process gis--process))
    (let ((out (generate-new-buffer " *gis-stdout*"))
          (err (generate-new-buffer " *gis-stderr*")))
      (setq gis--process
            (make-process
             :name "gis"
             :buffer out
             :command (cons gis-program args)
             :connection-type 'pipe
             :noquery t
             :stderr err
             :sentinel
             (lambda (proc _event)
               (unless (process-live-p proc)
                 (let ((stdout (with-current-buffer out (buffer-string)))
                       (stderr (with-current-buffer err (buffer-string)))
                       (status (process-exit-status proc)))
                   (gis--discard-buffer out)
                   (gis--discard-buffer err)
                   (when (buffer-live-p buf)
                     (with-current-buffer buf
                       (setq gis--process nil)
                       (funcall callback stdout stderr status))))))))
      (process-put gis--process 'gis-stderr err)
      ;; `:stderr' spawns a process of its own, which neither inherits
      ;; `:noquery' nor stays quiet about finishing.
      (when-let* ((errproc (get-buffer-process err)))
        (set-process-query-on-exit-flag errproc nil)
        (set-process-sentinel errproc #'ignore)))))

(defun gis--branches ()
  "Return the branch names known to gis, for completion.
Synchronous by necessity -- the caller prompts with the result."
  (let ((default-directory (gis--get-gis-marker)))
    (condition-case err
        ;; Split each line on whitespace, as the old
        ;; `(split-string (shell-command-to-string ...))' did -- gis prints
        ;; several branches per line.
        (mapcan #'split-string
                (process-lines gis-program "branches" "--no-module-name"))
      (error (user-error "Could not list gis branches: %s"
                         (error-message-string err))))))

;;; The status buffer
;;
;; One buffer per root, not the single "gis-mode" buffer there used to be:
;; that one reported on whichever root happened to create it, and drifted
;; between persp workspaces.  Matched on `gis--root' rather than on the
;; buffer name, which two roots can share.

(defun gis--status-buffer (root &optional create)
  "The status buffer reporting on ROOT, made when CREATE and there is none."
  (or (seq-find (lambda (buffer)
                  (with-current-buffer buffer
                    (and (derived-mode-p 'gis-status-mode)
                         (equal gis--root root))))
                (buffer-list))
      (when create
        (with-current-buffer
            (generate-new-buffer
             (format "*gis: %s*"
                     (file-name-nondirectory (directory-file-name root))))
          ;; The mode first: it runs `kill-all-local-variables'.
          (gis-status-mode)
          (setq-local gis--root root)
          ;; NOTE: `buffer-file-name' is deliberately left alone.  It used to
          ;; be pointed at the module root, but this is a `special-mode'
          ;; buffer that visits no file -- claiming to visit a *directory*
          ;; made Emacs offer to save it, let `find-file' on the root reuse
          ;; this buffer, and sent vc and the mode line looking for a branch
          ;; in a non-file buffer.  `default-directory' is what the commands
          ;; here actually use.
          (setq-local default-directory root)
          (setq-local revert-buffer-function
                      (lambda (&rest _) (gis--status-reload)))
          (when gis-auto-fetch-interval
            (setq-local gis--fetch-timer
                        (run-with-timer gis-auto-fetch-interval gis-auto-fetch-interval
                                         #'gis--auto-fetch (current-buffer)))
            ;; Local and one-shot: the buffer is being killed anyway, so
            ;; nothing else needs this hook afterward.
            (add-hook 'kill-buffer-hook
                      (lambda ()
                        (when (timerp gis--fetch-timer)
                          (cancel-timer gis--fetch-timer)))
                      nil t))
          (current-buffer)))))

(defun gis--status-refresh (&optional buffer)
  "Re-run `gis status' into BUFFER, current by default, displaying nothing.
Sentinels call this rather than `gis/status', which would take over
whatever window is selected whenever the command happens to finish."
  (with-current-buffer (or buffer (current-buffer))
    (gis-status-init '("status" "--format=json"))))

(defun gis--status-reload ()
  "Refresh the current status buffer, dropping the last command's markers."
  (setq gis--progress nil)
  (gis--status-refresh))

;;;###autoload
(defun gis/status ()
  "Show the status of every gis module of the current project as a table."
  (interactive)
  (let ((root (gis--get-gis-marker)))
    ;; Unlike `switch-to-buffer', obeys `display-buffer-alist', where the
    ;; popup rule in config.el lives.
    (pop-to-buffer-same-window (gis--status-buffer root t))
    (gis--status-reload)))

(defun gis--call-outside-panel (fn)
  "Call FN from the last ordinary window when a dedicated one is selected.
In the status popup, `find-file' would open inside it and magit would split
the code window.  FN keeps the current `default-directory'."
  (let ((dir default-directory)
        (window (and (window-dedicated-p) (get-mru-window nil nil t))))
    (when window (select-window window))
    (let ((default-directory dir))
      (funcall fn))))

(defun gis--anchored-panel ()
  "The status panel, when it is the frame's left-most full-height column."
  (when-let* ((window (window-child (frame-root-window))))
    (and (eq (window-parameter window 'window-side) 'left)
         (window-live-p window)
         (window-next-sibling window)
         (with-current-buffer (window-buffer window)
           (derived-mode-p 'gis-status-mode))
         window)))

(defun gis--beside-panel-a (make buffer &rest args)
  "Open a new side window beside the anchored status panel, not around it.
Doom's popups always split the frame root, which would push the panel inward
or under a bottom popup.  Leans on the window.el internal Doom also rebinds."
  (let ((panel (gis--anchored-panel)))
    (if (or (null panel)
            (with-current-buffer buffer (derived-mode-p 'gis-status-mode)))
        (apply make buffer args)
      (cl-letf (((symbol-function 'window--make-major-side-window-next-to)
                 (lambda (_side) (window-next-sibling panel))))
        (apply make buffer args)))))

(advice-add 'window--make-major-side-window :around #'gis--beside-panel-a)

;;;###autoload
(defun gis/eshell ()
  "`project-eshell' for the current project, outside the status panel."
  (interactive)
  (gis--call-outside-panel #'project-eshell))

(define-obsolete-function-alias 'gis/status-one-line #'gis/status "2026-08-26"
  "The one line and the expanded view were replaced by a single table.")

(defun gis-status-init (args)
  "Fill the current gis status buffer by running gis with ARGS asynchronously."
  (when gis--root (setq-local default-directory gis--root))
  (let ((module (gis--module-at-point)))
    (setq header-line-format (format "Running %s %s..."
                                     gis-program (string-join args " ")))
    (force-mode-line-update)
    (gis--run args
              (lambda (stdout stderr status)
                (gis--render-status stdout stderr status module)))))

;;; Reading the status document

(defun gis--parse-status (stdout)
  "Parse STDOUT as a gis status document, or return nil if it is not one.
`:false-object' matters as much as `:null-object' here: json.el's default
`:false' is truthy in elisp, which would make every module look detached
and every upstream gone."
  (condition-case nil
      (json-parse-string stdout
                         :object-type 'plist
                         :array-type 'list
                         :null-object nil
                         :false-object nil)
    (error nil)))

(defun gis--module-directories ()
  "Map each module's directory name to its path relative to the root.
The document names a module by its directory's basename -- gis builds it
from `path.getFileName()' -- so a nested submodule such as `libs/common'
arrives as `common' and only the marker file can resolve it back."
  (let (map)
    (dolist (path (gis--parse-modules) (nreverse map))
      (push (cons (file-name-nondirectory (directory-file-name path)) path) map))))

(defun gis--modules (data)
  "Modules of DATA, each carrying the `:dir' its name resolves to.
`:progress' is seeded from the last command's snapshot, which outlives it."
  (let ((dirs (gis--module-directories)))
    (mapcar (lambda (module)
              (let ((m (plist-put module :dir
                                  (if (plist-get module :root)
                                      "."
                                    (or (cdr (assoc (plist-get module :module) dirs))
                                        (plist-get module :module))))))
                (plist-put m :progress (gis--progress-state m gis--progress))))
            (plist-get data :modules))))

;;; Cells

(defconst gis--unmodified '(" " "" "?")
  "Status values that are not a modification.
gis reports the empty string for a status line shorter than two
characters, so testing for a space alone is not enough.")

(defun gis--branch-face (name)
  "Face for the branch NAME, by the same rule the CLI colors it with."
  (cond ((member name (gis--config "default_branches" gis-default-branches))
         'gis-default-branch)
        ((seq-some (lambda (prefix) (string-prefix-p prefix name))
                   (gis--config "feature_branch_prefixes" gis-feature-branch-prefixes))
         'gis-feature-branch)
        (t 'gis-other-branch)))

(defconst gis--progress-markers
  '(("pending"     "·" gis-dim)
    ("in-progress" "▸" gis-progress-running)
    ("done"        "✓" gis-progress-done)
    ("failed"      "✗" gis-progress-failed))
  "Marker and face for each state gis reports through `--progress'.")

(defun gis--cell-progress (module _table)
  "MODULE's state under the running gis command, a space when there is none.
Sorting this column groups the failures: space < · < ▸ < ✓ < ✗."
  (if-let* ((marker (assoc (plist-get module :progress) gis--progress-markers)))
      (propertize (nth 1 marker) 'face (nth 2 marker))
    " "))

(defun gis--progress-width ()
  "Width of the marker column, in the character widths vtable's `:width' counts.
It has to be stated rather than measured by vtable: vtable sizes a column
from the values present when the table is inserted and truncates anything
wider afterwards, and at insert time every row holds a space -- so a
marker taken from a fallback font would be clipped."
  (let ((unit (string-pixel-width (propertize "x" 'face 'gis-table)))
        (widest (apply #'max
                       (mapcar (lambda (marker)
                                 ;; Under the faces vtable will draw it with:
                                 ;; `error' and `warning' are bold in many
                                 ;; themes, and bold is wider.
                                 (string-pixel-width
                                  (propertize (nth 1 marker)
                                              'face (list (nth 2 marker) 'gis-table))))
                               gis--progress-markers))))
    (if (zerop unit) 1 (max 1 (ceiling (/ (float widest) unit))))))

(defun gis--cell-module (module _table)
  (let ((name (plist-get module :module)))
    (if (plist-get module :root)
        (propertize name 'face 'gis-root-module)
      name)))

(defun gis--cell-branch (module _table)
  "Name of the branch MODULE is on, marked when its upstream was deleted.
What it tracks and how far it has drifted is the Ahead/Behind column's
job; repeating the remote name here (almost always `origin') would only
be noise on every row for the rare row where it matters."
  (let ((branch (plist-get module :branch)))
    (cond
     ;; No branch line at all: either git failed for this module, or the
     ;; repository is in a state it printed nothing for.
     ((null branch) (propertize "—" 'face 'gis-detached))
     ((plist-get branch :detached) (propertize "HEAD(detached)" 'face 'gis-detached))
     (t (let ((name (plist-get branch :name)))
          (concat
           (propertize name 'face (gis--branch-face name))
           (when (plist-get branch :gone)
             (propertize "⇢gone" 'face 'gis-behind))))))))

(defun gis--cell-tracking (module _table)
  "How far MODULE has drifted from the branch it tracks.
Worded like the CLI does it, down to coloring the counts and leaving the
words plain."
  (let* ((branch (plist-get module :branch))
         (ahead (or (plist-get branch :ahead) 0))
         (behind (or (plist-get branch :behind) 0))
         (ahead-part (concat "ahead " (propertize (number-to-string ahead)
                                                  'face 'gis-ahead)))
         (behind-part (concat "behind " (propertize (number-to-string behind)
                                                    'face 'gis-behind))))
    ;; ahead/behind are 0 rather than absent when nothing is tracked, and stay
    ;; 0 once the upstream is gone, so the numbers only mean something when
    ;; there is an upstream still there to compare against.
    (cond ((or (null branch)
               (null (plist-get branch :upstream))
               (plist-get branch :gone))
           (propertize "—" 'face 'gis-dim))
          ((and (zerop ahead) (zerop behind)) (propertize "in sync" 'face 'gis-dim))
          ((zerop behind) ahead-part)
          ((zerop ahead) behind-part)
          (t (concat ahead-part ", " behind-part)))))

(defun gis--cell-changes (module _table)
  "Counts of staged, unstaged and untracked files of MODULE.
A file staged *and* modified counts on both sides, as in git's own short
format."
  (let ((staged 0) (unstaged 0) (untracked 0))
    (dolist (file (plist-get module :files))
      (let ((index (plist-get file :indexStatus))
            (worktree (plist-get file :worktreeStatus)))
        (if (and (equal index "?") (equal worktree "?"))
            (setq untracked (1+ untracked))
          (unless (member index gis--unmodified) (setq staged (1+ staged)))
          (unless (member worktree gis--unmodified) (setq unstaged (1+ unstaged))))))
    (if (and (zerop staged) (zerop unstaged) (zerop untracked))
        ;; A module git said nothing about has no clean tree to report -- the
        ;; check mark would be claiming one.  Dim rather than green either
        ;; way: this column is scanned for the modules needing attention, so
        ;; the settled ones should recede.
        (propertize (if (plist-get module :branch) "✓" "—") 'face 'gis-dim)
      (string-join
       (delq nil
             (list (and (> staged 0) (propertize (format "%dS" staged) 'face 'gis-staged))
                   (and (> unstaged 0) (propertize (format "%dM" unstaged) 'face 'gis-unstaged))
                   (and (> untracked 0) (propertize (format "%d?" untracked) 'face 'gis-dim))))
       " "))))

;;; Rendering

(defvar-local gis--table nil
  "The vtable currently displayed in this buffer, if any.")

(defun gis--module-at-point ()
  "Name of the module whose row point is on, if any."
  (plist-get (vtable-current-object) :module))

(defun gis--goto-module (name)
  "Put point on the row of the module called NAME.
`vtable-goto-object' compares with `eq', so it has to be handed the
object of the table just built -- the one saved before the refresh could
never match."
  (when-let* ((table gis--table)
              (object (seq-find (lambda (module)
                                  (equal (plist-get module :module) name))
                                (vtable-objects table))))
    (vtable-goto-object object)))

(defun gis--with-window (buffer render)
  "Call RENDER with BUFFER's window selected, when it has one.
vtable measures its columns against the selected window, and this runs
from a process sentinel, where that is wherever the user happens to be."
  (if-let* ((window (get-buffer-window buffer t)))
      (with-selected-window window (funcall render))
    (funcall render)))

(defun gis--header-line (data modules stderr)
  (concat
   (format "%d modules" (length modules))
   (when-let* ((fetched (plist-get data :fetchedAt)))
     (format " | fetched at %s" (string-replace "T" " " fetched)))
   ;; A module whose directory is missing, or that was cut short by the module
   ;; timeout, is left out of the document and reported on stderr only -- and
   ;; gis still exits 0 for the missing directory, so the status cannot carry
   ;; this on its own.
   (unless (string-empty-p (string-trim stderr))
     (propertize " | gis wrote to stderr, see *Messages*" 'face 'warning))))

(defun gis--insert-table (modules sort-by)
  "Insert a table of MODULES, keeping the previous SORT-BY.
Every column states its `:align': vtable otherwise guesses from the data,
and guesses `right' for all of them when there is no data at all."
  (let ((table (make-vtable
                ;; The marker has a column of its own because vtable sorts on
                ;; the getter's value: inside the Module cell it would sort the
                ;; modules by state.
                :columns (list (list :name ""        :align 'left
                                     :width (gis--progress-width)
                                     :getter #'gis--cell-progress)
                               (list :name "Module"  :align 'left  :getter #'gis--cell-module)
                               (list :name "Branch"  :align 'left  :getter #'gis--cell-branch)
                               (list :name "Ahead/Behind" :align 'left
                                     :getter #'gis--cell-tracking)
                               (list :name "Changes" :align 'left  :getter #'gis--cell-changes))
                :objects modules
                ;; Keeps `header-line-format' for the summary, and avoids the
                ;; header line minor mode being killed by a mode re-run.
                :use-header-line nil
                ;; vtable's own default face inherits `variable-pitch'.
                :face 'gis-table
                :keymap gis-status-vtable-map
                :insert nil)))
    (when sort-by (setf (vtable-sort-by table) sort-by))
    (vtable-insert table)
    table))

(defun gis--render-failure (stdout stderr status)
  "Report a run that produced no status document.
STATUS alone cannot name the problem: gis exits 0 while printing
something unparsable when its output is not what we asked for at all."
  (setq header-line-format
        (cond ((string-match-p "--format" stderr)
               (format "%s does not understand --format=json, rebuild it" gis-program))
              ((/= status 0) (format "%s failed (status %d)" gis-program status))
              (t (format "%s printed no status document" gis-program))))
  ;; stderr is where gis explains itself; fall back to stdout so unparsable
  ;; output is shown rather than swallowed.
  (let ((text (if (string-empty-p (string-trim stderr)) stdout stderr)))
    (insert (if (string-empty-p (string-trim text))
                "gis produced no output."
              (ansi-color-apply text)))))

(defun gis--render-status (stdout stderr status module)
  "Render the status document STDOUT as a table, putting point on MODULE.
STDERR and STATUS come from the same run.  The document is parsed first
and the status only consulted afterwards, because gis exits non-zero as
soon as one module's git command failed while still printing a complete
document."
  (let ((buffer (current-buffer)))
    (unless (string-empty-p (string-trim stderr))
      (message "gis: %s" (string-trim stderr)))
    (gis--with-window
     buffer
     (lambda ()
       (let ((inhibit-read-only t)
             (data (gis--parse-status stdout))
             (sort-by (and gis--table (vtable-sort-by gis--table))))
         (erase-buffer)
         (setq gis--table nil)
         (if (null data)
             (gis--render-failure stdout stderr status)
           (let ((modules (gis--modules data)))
             (setq header-line-format (gis--header-line data modules stderr))
             (if (null modules)
                 ;; An empty vtable spreads its columns over the whole window,
                 ;; so there is nothing to draw here.
                 (insert "No modules.")
               (setq gis--table (gis--insert-table modules sort-by))
               (when module (gis--goto-module module)))))
         (set-buffer-modified-p nil))))))

;;; Running a gis command
;;
;; Nothing here displays a buffer.  This used to end in `gis/status', whose
;; `switch-to-buffer' then fired from a sentinel: a fetch finishing after
;; you had moved on took over the window you were looking at, and persp-mode
;; adopted the gis buffer into that workspace.  The result lands in the
;; root's status buffer whether or not it is on screen.
;;
;; Arguments come as a list rather than a shell command line, so that
;; `--progress' can be appended and names need no quoting.

(defun gis--progress-parse (line)
  "Parse LINE, one `--progress' snapshot, into an alist of module to state.
Returns nil for gis's own ERROR and WARNING lines, which share the stream."
  (when (string-prefix-p "{" line)
    (condition-case nil
        (mapcar (lambda (entry)
                  (cons (symbol-name (car entry))
                        (alist-get 'status (cdr entry))))
                (json-parse-string line :object-type 'alist :array-type 'list))
      (error nil))))

(defun gis--progress-state (module snapshot)
  "MODULE's state in SNAPSHOT.
`:dir' is tried first because gis keys a snapshot by basename but falls
back to the root-relative path -- what `:dir' holds -- when two modules
share one."
  (let ((dir (plist-get module :dir)))
    (cdr (or (and dir (assoc dir snapshot))
             (assoc (plist-get module :module) snapshot)
             (and dir (assoc (expand-file-name dir gis--root) snapshot))))))

(defun gis--apply-progress (snapshot)
  "Redraw the rows of `gis--table' whose state changed in SNAPSHOT."
  (when gis--table
    (gis--with-window
     (current-buffer)
     (lambda ()
       (save-excursion
         ;; `vtable-beginning-of-table' needs point on text carrying the table.
         (goto-char (point-min))
         (dolist (module (vtable-objects gis--table))
           (let ((state (gis--progress-state module snapshot)))
             (unless (equal state (plist-get module :progress))
               (plist-put module :progress state)
               (vtable-update-object gis--table module)))))))))

(defun gis--make-progress-filter (buffer)
  "Return a stderr filter feeding the marker column of BUFFER's table.
Each line is a snapshot of every module, so only the newest one matters."
  (let ((pending ""))
    (lambda (_proc output)
      (let* ((lines (split-string (concat pending output) "\n"))
             (complete (butlast lines)))
        ;; What followed the last newline: a partial line, or "".
        (setq pending (car (last lines)))
        (when (and complete (buffer-live-p buffer))
          (with-current-buffer buffer
            (setq gis--command-log
                  (nconc gis--command-log
                         (seq-remove (lambda (line)
                                       (or (string-prefix-p "{" line)
                                           (string-empty-p (string-trim line))))
                                     complete)))
            (when-let* ((snapshot (seq-some #'gis--progress-parse
                                            (reverse complete))))
              (setq gis--progress snapshot)
              (gis--apply-progress snapshot))))))))

(defun gis--command-start (buffer label)
  "Mark BUFFER, when there is one, as running a gis command doing LABEL."
  (when buffer
    (with-current-buffer buffer
      (setq gis--command-label label
            gis--command-log nil
            gis--progress nil)
      (setq-local mode-line-process (format " %s" label))
      (force-mode-line-update)
      ;; A command with no progress stream would otherwise leave the last
      ;; one's markers standing for its whole run.
      (gis--apply-progress nil))))

(defun gis--command-finished (buffer label status fallback)
  "Report the exit of the LABEL command with STATUS and refresh BUFFER.
FALLBACK is its stdout, quoted only when stderr said nothing."
  (let ((log (and (buffer-live-p buffer)
                  (buffer-local-value 'gis--command-log buffer))))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (setq gis--command-process nil
              gis--command-label nil)
        (setq-local mode-line-process nil)
        (force-mode-line-update)
        ;; The stderr pipe is a process of its own and is deleted with the
        ;; command, so its last snapshot can be lost.  A module left mid-flight
        ;; would then keep its marker for good, the states now outliving the
        ;; command -- drop what did not reach a final state instead.
        (setq gis--progress
              (seq-filter (lambda (state)
                            (member (cdr state) '("done" "failed")))
                          gis--progress))
        (gis--status-refresh)))
    (let ((warnings (string-trim (string-join log "\n"))))
      (cond
       ((/= status 0)
        (let ((text (string-trim (string-join (or log (list fallback)) "\n"))))
          (message "gis %s failed (status %d)%s" label status
                   (if (string-empty-p text)
                       ""
                     (concat ": " (ansi-color-apply text))))))
       ;; gis exits 0 after aborting whatever it could not finish inside
       ;; `module_timeout_seconds', so a clean status is not a clean run: the
       ;; aborted modules were never fetched, and their rows go on showing
       ;; what they showed before.
       ((not (string-empty-p warnings))
        (message "gis %s finished: %s" label (ansi-color-apply warnings)))
       (t (message "gis %s finished." label))))))

(defun gis--run-command (args label buffer)
  "Run `gis-program' with ARGS, reporting progress into BUFFER as LABEL.
The streams are kept apart because `--progress' writes to stderr; stdout
is collected only so that a failure has something to quote."
  (gis--command-start buffer label)
  (let* ((out (generate-new-buffer " *gis-command-stdout*"))
         (err (generate-new-buffer " *gis-command-stderr*"))
         (proc (make-process
                :name "gis-command"
                :buffer out
                :command (cons gis-program args)
                :connection-type 'pipe
                :noquery t
                :stderr err
                :sentinel
                (lambda (proc _event)
                  (unless (process-live-p proc)
                    (let ((status (process-exit-status proc))
                          (stdout (with-current-buffer out (buffer-string))))
                      (gis--discard-buffer out)
                      (gis--discard-buffer err)
                      (gis--command-finished buffer label status stdout)))))))
    ;; As in `gis--run': the `:stderr' process inherits neither `:noquery'
    ;; nor silence about finishing.
    (when-let* ((errproc (get-buffer-process err)))
      (set-process-query-on-exit-flag errproc nil)
      (set-process-sentinel errproc #'ignore)
      (when buffer
        (set-process-filter errproc (gis--make-progress-filter buffer))))
    (when buffer
      (with-current-buffer buffer (setq gis--command-process proc)))
    proc))

(defun gis--auto-fetch (buffer)
  "Run `gis fetch' in BUFFER unless a command is already running there.
Called from `gis--fetch-timer'; skips silently rather than erroring, since
there is no interactive context to report a `user-error' to."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (unless (process-live-p gis--command-process)
        (gis--run-command '("fetch" "--progress") "auto-fetching" buffer)))))

(defun gis--command-buffer (root)
  "The status buffer of ROOT, refusing while a command is running in it.
Nil when there is none, in which case the command runs unwatched."
  (let ((buffer (gis--status-buffer root)))
    (when (and buffer
               (process-live-p (buffer-local-value 'gis--command-process buffer)))
      (user-error "gis %s is already running in %s"
                  (buffer-local-value 'gis--command-label buffer)
                  (buffer-name buffer)))
    buffer))

(defun gis--call-gis-function (args label)
  "Run `gis' with ARGS for the current project, reported as LABEL."
  (let* ((root (gis--get-gis-marker))
         (buffer (gis--command-buffer root))
         (default-directory root))
    (gis--run-command args label buffer)
    (message "gis %s..." label)))

(defun gis--call-gis-shell (cmd label)
  "Run the shell command CMD for the current project, reported as LABEL.
`gis rm' has no flag to skip its prompt, so it still needs a `yes |'
pipeline -- and with a shell in the way, no stderr to read progress from."
  (let* ((root (gis--get-gis-marker))
         (buffer (gis--command-buffer root))
         (default-directory root))
    (gis--command-start buffer label)
    (let ((proc (start-process-shell-command "gis-command" nil cmd)))
      (set-process-query-on-exit-flag proc nil)
      (set-process-sentinel
       proc
       (lambda (proc _event)
         (unless (process-live-p proc)
           (gis--command-finished buffer label (process-exit-status proc) ""))))
      (when buffer
        (with-current-buffer buffer (setq gis--command-process proc))))
    (message "gis %s..." label)))

;;;###autodef
(defun gis/magit-status-at-point()
  "Open `magit-status' for the module of the row at point."
  (interactive)
  (let* ((object (or (vtable-current-object) (user-error "No module at point")))
         (dir (expand-file-name (or (plist-get object :dir) ".") (gis--get-gis-marker))))
    (gis--call-outside-panel
     (lambda ()
       ;; Over another module's magit, Doom's display function would split the
       ;; code window rather than replace it.
       (let ((display-buffer-overriding-action
              '((display-buffer-reuse-window display-buffer-same-window))))
         (magit-status-setup-buffer dir))))))

;;;###autoload
(defun gis/magit-status-or-status ()
  "`magit-status', except inside a gis buffer, where `SPC g g' refreshes it.
`default-directory' there is the gis root, not a module -- opening magit on
it is never useful, and `RET'/`gis/magit-status-at-point' already covers
the module at point."
  (interactive)
  (if (derived-mode-p 'gis-status-mode)
      (call-interactively #'gis--refresh-dispatch)
    (call-interactively #'magit-status)))

;;;###autodef
(defun gis/create-branch()
  (interactive)
  (let* ((completion-ignore-case t)
         (default-directory (gis--get-gis-marker))
         (branchName (read-string "Create branch: "))
         (modules (completing-read-multiple "Modules: "
                                            (gis--parse-modules)
                                            #'prot-common-crm-exclude-selected-p)))
    (gis--call-gis-function (append (list "cb" branchName) modules)
                            "branching")))

;;;###autodef
(defun gis/delete-branch()
  (interactive)
  (require 'consult)
  (let* ((completion-ignore-case t)
         (default-directory (gis--get-gis-marker))
         (branches (gis--branches))
         (branchName (consult--read branches :prompt "Branch to delete: ")))
    (gis--call-gis-shell (format "yes | %s rm %s" gis-program
                                 (shell-quote-argument branchName))
                         "deleting branch")))

;;;###autodef
(defun gis/push(&rest args)
  (interactive)
  (require 'consult)
  (let* ((completion-ignore-case t)
         (default-directory (gis--get-gis-marker))
         (branches (gis--branches))
         (branchName (consult--read branches :prompt "Branch to push: ")))
    (gis--call-gis-function
     (append (list "push" branchName "--no-interactive" "--progress")
             ;; transient hands its arguments back as "-f ", trailing space
             ;; and all, which gis would reject as an argv entry.
             (seq-remove #'string-empty-p
                         (mapcar #'string-trim (flatten-list args))))
     "pushing")))

;;;###autodef
(defun gis/fetch()
  (interactive)
  (gis--call-gis-function '("fetch" "--progress") "fetching"))

;;;###autodef
(defun gis/pull()
  (interactive)
  (gis--call-gis-function '("pull" "--progress") "pulling"))

;;;###autodef
(defun gis/yank-branch-name ()
  "Copy the branch of the module of the row at point.
The status document already carries it, so this no longer has to ask git."
  (interactive)
  (let* ((object (or (vtable-current-object) (user-error "No module at point")))
         (branch (plist-get (plist-get object :branch) :name)))
    (unless branch
      (user-error "No branch reported for module '%s'" (plist-get object :module)))
    (kill-new branch)
    (message "'%s' copied." branch)))

;;;###autodef
(defun gis/remote-prune-origin()
  "Run `git remote prune origin' on each submodule"
  (interactive)
  (gis--call-gis-function '("remote-prune-origin" "--progress") "pruning"))

;;;###autodef
(defun gis/prune-local-merged-branch()
  "Run `git remote prune origin' on each submodule"
  (interactive)
  (require 'consult)
  (let* ((completion-ignore-case t)
         (default-directory (gis--get-gis-marker))
         (branches (gis--branches))
         (branchName (consult--read branches :prompt "Base branch: ")))
    (gis--call-gis-function (list "prune" branchName "--progress") "pruning")))

;;;###autodef
(defun gis/rebase-current-origin()
  (interactive)
  (gis--call-gis-function '("rebase-current-origin" "--progress") "rebasing"))

;;;###autodef
(defun gis/find-modified-files()
  (interactive)
  (require 'consult)
  (let* ((default-directory (gis--get-gis-marker)) ;; FIXME: this changes the modeline directory
         ;; Synchronous: the completion prompt below needs the candidates.
         ;; `process-lines' keeps it off the shell and turns a gis failure
         ;; into an error rather than a list of stderr lines.
         (raw-candidates (process-lines gis-program "files"))
         ;; `gis files' prints module-relative paths, so this is the root
         ;; they are relative to.  Was "", which resolved to the same thing
         ;; only by way of `file-relative-name' falling back on
         ;; `default-directory'.
         (candidates (mm--get-file-names raw-candidates default-directory))
         (selected (consult--read candidates
                                  :lookup (lambda (selected &rest _) (cdr (assoc selected candidates)))
                                  :group
                                  (lambda (cand transform)
                                    (if transform
                                        cand
                                      ;; A path with no directory part (a file
                                      ;; at the module root) has no second
                                      ;; field; group those under "/".
                                      (let ((dir (cadr (split-string cand "\s" t))))
                                        (if dir
                                            (upcase (car (file-name-split dir)))
                                          "/"))))
                                  :prompt "Find (modified vc) file: ")))
    (gis--call-outside-panel (lambda () (find-file selected))))
  (setq this-command 'find-file))

(transient-define-suffix gis--fetch-dispatch()
  :description "gis fetch"
  (interactive)
  (gis/fetch))

(transient-define-suffix gis--refresh-dispatch()
  :description "gis refresh"
  (interactive)
  (gis/status))

(transient-define-suffix gis--checkout-dispatch(branch)
  :description "gis checkout branch"
  (interactive
   (let* ((completion-ignore-case t)
          (default-directory (gis--get-gis-marker))
          (branches (gis--branches)))
     (list (completing-read "Checkout branch: " branches))))
  (gis--call-gis-function (list "co" branch "--progress") "checking out"))

(transient-define-suffix gis--spin-out-dispatch()
  :description "gis spin out"
  (interactive)
  (gis/create-branch))

(transient-define-suffix gis--delete-dispatch()
  :description "gis delete branch"
  (interactive)
  (gis/delete-branch))

(transient-define-suffix gis--pull-dispatch()
  :description "gis pull"
  (interactive)
  (gis/pull))

(transient-define-suffix gis--push-dispatch(args)
  :description "gis push"
  (interactive (list (gis-push-arguments)))
  (gis/push args))

(transient-define-suffix gis--rebase-origin-dispatch(branch)
  :description "gis rebase origin"
  (interactive
   (let* ((completion-ignore-case t)
          (default-directory (gis--get-gis-marker))
          (branches (gis--branches)))
     (list (completing-read "Rebase on branch: " branches))))
  (gis--call-gis-function (list "rebase-origin" branch "--progress") "rebasing"))

(transient-define-suffix gis--rebase-current-origin-dispatch()
  :description "gis rebase current origin"
  (interactive)
  (gis/rebase-current-origin))


(transient-define-prefix gis-dispatch-f()
  "Gis transient prefix for refresh or fetch."
  ["Refresh & Status"
   ("f" "refresh" gis--refresh-dispatch)
   ("r" "refresh" gis--refresh-dispatch)
   ("u" "fetch" gis--fetch-dispatch)])

(transient-define-prefix gis-dispatch-branch()
  "Gis transient prefix for branch commands."
  ["Branching"
   ("b" "checkout" gis--checkout-dispatch)
   ("s" "spin-out" gis--spin-out-dispatch)
   ("x" "delete" gis--delete-dispatch)])

(transient-define-prefix gis-dispatch-pull()
  "Gis transient prefix for pull."
  ["Pull"
   ("u" "pull from remote origin" gis--pull-dispatch)])

(transient-define-prefix gis-dispatch-rebase()
  "Gis transient prefix for rebase."
  ["Rebase & Pull"
   ("e" "rebase on specified branch" gis--rebase-origin-dispatch)
   ("u" "rebase current origin" gis--rebase-current-origin-dispatch)])

(transient-define-prefix gis-dispatch-push()
  "Gis transient prefix for push."
  ["Arguments"
   ("-f" "force push" "-f ")
   ("-r" "push to remote" "-r ")]
  ["Push"
   ("u" "push to remote origin" gis--push-dispatch)])

(defun gis-push-arguments ()
  (transient-args 'gis-dispatch-push))

(transient-define-prefix gis-dispatch()
  "Gis transient prefix for all commands."
  ["All Gis Commands"
   ("b" "Branching" gis-dispatch-branch)
   ("f" "Refresh & Status" gis-dispatch-f)
   ("g" "Refresh & Status" gis-dispatch-f)
   ("F" "Pull" gis-dispatch-pull)
   ("p" "Push" gis-dispatch-push)
   ("r" "Rebase" gis-dispatch-rebase)])
