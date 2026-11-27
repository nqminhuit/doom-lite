;;; completion/vertico/autoload/vertico.el -*- lexical-binding: t; -*-

;;;###autoload
(cl-defun +vertico-file-search (&key query in all-files (recursive t) prompt args)
  "Conduct a file search using ripgrep.

:query STRING
  Determines the initial input to search for.
:in PATH
  Sets what directory to base the search out of. Defaults to the current
  project's root.
:recursive BOOL
  Whether or not to search files recursively from the base directory.
:args LIST
  Arguments to be appended to `consult-ripgrep-args'."
  (declare (indent defun))
  (unless (executable-find "rg" t)
    (user-error "Couldn't find ripgrep in your PATH"))
  (require 'consult)
  (setq deactivate-mark t)
  (let* ((project-root (or (doom-project-root) default-directory))
         (directory (or in project-root))
         (prompt (if (stringp prompt) (string-trim prompt) "Search"))
         (query (or query
                    (when (doom-region-active-p)
                      (regexp-quote (doom-region t))))))
    (dlet ((consult-ripgrep-args
            (concat "rg "
                    (if all-files "-uu ")
                    (unless recursive "--maxdepth 1 ")
                    "--null --line-buffered --color=never --max-columns=1000 "
                    "--path-separator /   --smart-case --no-heading "
                    "--with-filename --line-number --search-zip "
                    "--hidden -g !.git -g !.svn -g !.hg "
                    (mapconcat #'identity args " ")))
           (consult-async-split-style consult-async-split-style)
           (consult-async-split-styles-alist
            (copy-sequence consult-async-split-styles-alist)))
      ;; Change the split style if the initial query contains the separator.
      (when query
        (cl-destructuring-bind (&key separator initial function)
            (alist-get consult-async-split-style consult-async-split-styles-alist)
          ;; Perl async split style starts with an #. If the query contains #,
          ;; then use oneof the alternative delimiters instead.
          (if (eq consult-async-split-style 'perl)
              (when (string-match-p (char-to-string initial) query)
                (setf (alist-get 'perlalt consult-async-split-styles-alist)
                      `(:initial ,(or (cl-loop for char in (list "%" "@" "!" "&" "/" ";")
                                               unless (string-match-p char query)
                                               return char)
                                      "%")
                        :separator ,separator
                        :function ,function)
                      consult-async-split-style 'perlalt))
            ;; If the separator character is present *in* the query, escape them.
            (when separator
              (setq query
                    (replace-regexp-in-string (regexp-quote (char-to-string separator))
                                              (concat "\\" (char-to-string separator))
                                              query t t))))))
      (consult--grep prompt #'consult--ripgrep-make-builder directory query))))

;;;###autoload
(defun +vertico/project-search (&optional arg initial-query directory)
  "Performs a live project search from the project root using ripgrep.
If ARG (universal argument), include all files, even hidden or compressed ones,
in the search."
  (interactive "P")
  (+vertico-file-search :query initial-query :in directory :all-files arg))

;;;###autoload
(defun +vertico/project-search-from-cwd (&optional arg initial-query)
  "Performs a live project search from the current directory.
If ARG (universal argument), include all files, even hidden or compressed ones."
  (interactive "P")
  (+vertico/project-search arg initial-query default-directory))

;;;###autoload
(defun +vertico/search-symbol-at-point ()
  "Performs a search in the current buffer for thing at point."
  (interactive)
  (consult-line (thing-at-point 'symbol)))

;;;###autoload
(defun +vertico-embark-target-package-fn ()
  "Targets Doom's package! statements and returns the package name"
  (when (or (derived-mode-p 'emacs-lisp-mode) (derived-mode-p 'org-mode))
    (save-excursion
      (when (and (search-backward "(" nil t)
                 (looking-at "(\\s-*package!\\s-*\\(\\(\\sw\\|\\s_\\)+\\)\\s-*"))
        (let ((pkg (match-string 1)))
          (set-text-properties 0 (length pkg) nil pkg)
          `(package . ,pkg))))))

;;;###autoload
(defun +vertico/embark-export-write ()
  "Export the current vertico results to a writable buffer if possible.

Supports exporting consult-grep to grep-edit-mode, file to wdired,
consult-location to occur-edit, and consult-xref to xref-edit-mode (both
grep-edit-mode and xref-edit-mode need Emacs 31+)."
  (interactive)
  (require 'embark)
  (dlet ((embark-after-export-hook
          `(,@embark-after-export-hook
            ,(pcase-let ((`(,type . _)
                          (run-hook-with-args-until-success 'embark-candidate-collectors)))
               (pcase type
                 ('consult-grep #'grep-change-to-grep-edit-mode)
                 ('file #'wdired-change-to-wdired-mode)
                 ('consult-location #'occur-edit-mode)
                 ('consult-xref (if (fboundp 'xref-change-to-xref-edit-mode)
                                    #'xref-change-to-xref-edit-mode
                                  (user-error "Writable xref export requires Emacs 31+")))
                 (x (user-error "embark category %S doesn't support writable export" x)))))))
    (embark-export)))

;;;###autoload
(defun +vertico/embark-preview ()
  "Previews candidate in vertico buffer, unless it's a consult command"
  (interactive)
  (unless (bound-and-true-p consult--preview-function)
    (unless (require 'embark nil t)
      (user-error "Embark not installed, aborting..."))
    (save-selected-window
      (dlet (embark-quit-after-action)
        (embark-dwim)))))

;;;###autoload
(defun +vertico/enter-or-preview ()
  "Enter directory or embark preview on current candidate."
  (interactive)
  (when (> 0 vertico--index)
    (user-error "No vertico session is currently active"))
  (if (and (let ((cand (vertico--candidate)))
             (or (string-suffix-p "/" cand)
                 (and (vertico--remote-p cand)
                      (string-suffix-p ":" cand))))
           (not (equal vertico--base ""))
           (eq 'file (vertico--metadata-get 'category)))
      (vertico-insert)
    (condition-case _
        (+vertico/embark-preview)
      (user-error (vertico-directory-enter)))))

;;;###autoload
(defun +vertico/jump-list (jump)
  "Go to an entry in evil's jumplist."
  (interactive
   (let (buffers)
     (require 'consult)
     (unwind-protect
         (list
          (consult--read
           (delete-dups
            (delq
             nil (mapcar
                  (lambda (jump)
                    (cl-destructuring-bind (pos path) jump
                      (let ((pt (if (markerp pos) (marker-position pos) pos)))
                        (when (and pt path (file-exists-p path))
                          (let* ((visiting (find-buffer-visiting path))
                                 (buf (or visiting (find-file-noselect path t)))
                                 (dir default-directory))
                            (unless visiting
                              (push buf buffers))
                            (with-current-buffer buf
                              (goto-char (min pt (point-max)))
                              ;; Fontifying moves point; keep it on the jump's line.
                              (save-excursion
                                (font-lock-fontify-region
                                 (line-beginning-position) (line-end-position)))
                              (format "%s:%d: %s"
                                      (car (cl-sort (list (abbreviate-file-name (buffer-file-name buf))
                                                          (file-relative-name (buffer-file-name buf) dir))
                                                    #'< :key #'length))
                                      (line-number-at-pos)
                                      (string-trim-right (or (thing-at-point 'line) "")))))))))
                  (ring-elements (evil--jumps-get-jumps (evil--jumps-get-current))))))
           :prompt "jumplist: "
           :sort nil
           :require-match t
           :category 'jump-list))
       (mapc #'kill-buffer buffers))))
  (if (not (string-match "^\\([^:]+\\):\\([0-9]+\\): " jump))
      (user-error "No match")
    (let ((file (match-string-no-properties 1 jump))
          (line (match-string-no-properties 2 jump)))
      (find-file file)
      (goto-char (point-min))
      (forward-line (1- (string-to-number line))))))

;;;###autoload
(defun +vertico/consult-fd-or-find (&optional dir initial)
  "Runs consult-fd if fd version > 8.6.0 exists, consult-find otherwise.
See minad/consult#770."
  (interactive "P")
  ;; REVIEW: This condition was adapted from a similar one in
  ;;   lisp/doom-projects.el, to be replaced with a more robust check post v3
  (if (when-let*
          ((bin (if (ignore-errors (file-remote-p default-directory nil t))
                    (cl-find-if (doom-rpartial #'executable-find t)
                                (list "fdfind" "fd"))
                  doom-fd-executable))
           (version (with-memoization (get 'doom-fd-executable 'version)
                      (cadr (split-string (cdr (doom-call-process bin "--version"))
                                          " " t))))
           ((ignore-errors (version-to-list version))))
        ;; REVIEW: Remove once fd 8.6.0 is widespread enough.
        (version< "8.6.0" version))
      (consult-fd dir initial)
    (consult-find dir initial)))

;;;###autoload
(defun +vertico-basic-remote-try-completion (string table pred point)
  (and (vertico--remote-p string)
       (completion-basic-try-completion string table pred point)))

;;;###autoload
(defun +vertico-basic-remote-all-completions (string table pred point)
  (and (vertico--remote-p string)
       (completion-basic-all-completions string table pred point)))

;;;###autoload
(defun +vertico-orderless-dispatch (pattern _index _total)
  "Like `orderless-affix-dispatch', but allows affixes to be escaped."
  (let ((len (length pattern))
        (alist orderless-affix-dispatch-alist))
    (when (> len 0)
      (cond
       ;; Ignore single dispatcher character
       ((and (= len 1) (alist-get (aref pattern 0) alist)) #'ignore)
       ;; Prefix
       ((when-let* ((style (alist-get (aref pattern 0) alist))
                    ((not (char-equal (aref pattern (max (1- len) 1)) ?\\))))
          (cons style (substring pattern 1))))
       ;; Suffix
       ((when-let* ((style (alist-get (aref pattern (1- len)) alist))
                    ((not (char-equal (aref pattern (max 0 (- len 2))) ?\\))))
          (cons style (substring pattern 0 -1))))))))

;; Recognizes the following patterns:
;; * .ext (file extension)
;; * regexp$ (regexp matching at end)
;;;###autoload
(defun +vertico-orderless-disambiguation-dispatch (word _index _total)
  (let ((tofu-re
         (if (boundp 'consult--tofu-regexp)
             (concat consult--tofu-regexp "*\\'")
           "\\'")))
    (cond
     ;; Ensure that $ works with Consult commands, which add disambiguation suffixes
     ((string-suffix-p "$" word)
      `(orderless-regexp . ,(concat (substring word 0 -1) tofu-re)))
     ;; File extensions
     ((and (or minibuffer-completing-file-name
               (derived-mode-p 'eshell-mode))
           (string-match-p "\\`\\.." word))
      `(orderless-regexp . ,(concat "\\." (substring word 1) tofu-re))))))

;;; vertico.el ends here
