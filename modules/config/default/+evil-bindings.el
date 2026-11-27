;;; config/default/+bindings.el -*- lexical-binding: t; -*-

;; NOTE: SPC u replaces C-u as the universal argument.

;; Minibuffer
(map! :map (evil-ex-completion-map evil-ex-search-keymap)
      "C-a" #'evil-beginning-of-line
      "C-b" #'evil-backward-char
      "C-f" #'evil-forward-char
      :gi "C-j" #'next-complete-history-element
      :gi "C-k" #'previous-complete-history-element)

(define-key! :keymaps +default-minibuffer-maps
  [escape] #'abort-recursive-edit
  "C-a"    #'move-beginning-of-line
  "C-r"    #'evil-paste-from-register
  "C-u"    #'evil-delete-back-to-indentation
  "C-w"    #'doom/delete-backward-word
  "C-z"    (cmd! (ignore-errors (call-interactively #'undo))))

(define-key! :keymaps +default-minibuffer-maps
  "C-j"    #'next-line
  "C-k"    #'previous-line
  "C-S-j"  #'scroll-up-command
  "C-S-k"  #'scroll-down-command)
;; For folks with `evil-collection-setup-minibuffer' enabled
(define-key! :states 'insert :keymaps +default-minibuffer-maps
  "C-j"    #'next-line
  "C-k"    #'previous-line)
(define-key! read-expression-map
  "C-j" #'next-line-or-history-element
  "C-k" #'previous-line-or-history-element)


;;
;;; Global keybindings

;; Smart tab, these will only work in GUI Emacs
(map! :i [tab]
      `(menu-item "Evil insert smart tab" nil :filter
        (lambda (cmd)
          (cond
           ((or (doom-lookup-key [tab] overriding-terminal-local-map)
                (doom-lookup-key (kbd "TAB") overriding-terminal-local-map))
            cmd)
           ((and (bound-and-true-p corfu-mode)
                 corfu--candidates)
            (if (derived-mode-p 'eshell-mode 'comint-mode)
                #'completion-at-point
              #'indent-for-tab-command)))))
      :m [tab]
      `(menu-item "Evil motion smart tab" nil :filter
        (lambda (cmd)
          (cond
           ((or (doom-lookup-key [tab] overriding-terminal-local-map)
                (doom-lookup-key (kbd "TAB") overriding-terminal-local-map))
            cmd)
           ;; Fixes doomemacs/core#4548: without this, this tab keybind
           ;; overrides mode-local ones for modes that don't have an evil
           ;; keybinding scheme or users who don't have :editor (evil
           ;; +everywhere) enabled.
           ((or (doom-lookup-key
                 [tab]
                 (list (evil-get-auxiliary-keymap (current-local-map)
                                                  evil-state)
                       (current-local-map)))
                (doom-lookup-key
                 (kbd "TAB")
                 (list (evil-get-auxiliary-keymap (current-local-map)
                                                  evil-state)))
                (doom-lookup-key (kbd "TAB") (list (current-local-map))))
            cmd)
           ((fboundp 'evil-jump-item)
            #'evil-jump-item))))

      (:after apropos :map apropos-mode-map
       :n "TAB"     #'forward-button
       :n [tab]     #'forward-button
       :n [backtab] #'backward-button)
      (:after view :map view-mode-map
       [escape]  #'View-quit-all)
      (:after man :map Man-mode-map
       :n "q"    #'kill-current-buffer)

      ;; misc
      :n "C-S-f"  #'toggle-frame-fullscreen
      :n "C-+"    #'doom/reset-font-size
      ;; Buffer-local font resizing
      :n "C-="    #'text-scale-increase
      :n "C--"    #'text-scale-decrease
      ;; Frame-local font resizing
      :n "M-C-="  #'doom/increase-font-size
      :n "M-C--"  #'doom/decrease-font-size)


;;
;;; Module keybinds

;;; :completion (in-buffer)
(map! (:after corfu
       (:map corfu-mode-map
        (:unless (bound-and-true-p evil-disable-insert-state-bindings)
         :i "C-@"   #'completion-at-point
         :i "C-SPC" #'completion-at-point
         :i "C-n"   #'+corfu/dabbrev-or-next
         :i "C-p"   #'+corfu/dabbrev-or-last)
        :n "C-SPC" (cmd! (call-interactively #'evil-insert-state)
                         (call-interactively #'completion-at-point))
        :v "C-SPC" (cmd! (call-interactively #'evil-change)
                         (call-interactively #'completion-at-point)))
       (:map corfu-map
        (:unless (bound-and-true-p evil-disable-insert-state-bindings)
         :i "C-SPC" #'corfu-insert-separator)
        "C-k" #'corfu-previous
        "C-j" #'corfu-next
        "C-u" (cmd! (let (corfu-cycle)
                      (funcall-interactively #'corfu-next (- corfu-count))))
        "C-d" (cmd! (let (corfu-cycle)
                      (funcall-interactively #'corfu-next corfu-count)))))
      (:after corfu-popupinfo
       :map corfu-popupinfo-map
       "C-h"      #'corfu-popupinfo-toggle
       ;; Reversed because popupinfo assumes opposite of what feels intuitive
       ;; with evil.
       "C-S-k"    #'corfu-popupinfo-scroll-down
       "C-S-j"    #'corfu-popupinfo-scroll-up
       "C-<up>"   #'corfu-popupinfo-scroll-down
       "C-<down>" #'corfu-popupinfo-scroll-up
       "C-S-p"    #'corfu-popupinfo-scroll-down
       "C-S-n"    #'corfu-popupinfo-scroll-up
       "C-S-u"    (cmd!! #'corfu-popupinfo-scroll-down nil corfu-popupinfo-min-height)
       "C-S-d"    (cmd!! #'corfu-popupinfo-scroll-up nil corfu-popupinfo-min-height)))


;;; :ui
(map! "C-`" #'window-toggle-side-windows

      (:when (modulep! :ui workspaces)
       :n "C-t"   #'+workspace/new
       :n "C-S-t" #'+workspace/display
       :g "M-1"   #'+workspace/switch-to-0
       :g "M-2"   #'+workspace/switch-to-1
       :g "M-3"   #'+workspace/switch-to-2
       :g "M-4"   #'+workspace/switch-to-3
       :g "M-5"   #'+workspace/switch-to-4
       :g "M-6"   #'+workspace/switch-to-5
       :g "M-7"   #'+workspace/switch-to-6
       :g "M-8"   #'+workspace/switch-to-7
       :g "M-9"   #'+workspace/switch-to-8
       :g "M-0"   #'+workspace/switch-to-final))

;;
;;; <leader>

(map! :leader
      :desc "Eval expression"       ";"    #'pp-eval-expression
      :desc "M-x"                   ":"    #'execute-extended-command
      :desc "Toggle scratch buffer" "x"    #'doom/toggle-scratch-buffer
      ;; C-u is used by evil
      :desc "Universal argument"    "u"    #'universal-argument
      :desc "window"                "w"    #'evil-window-map
      :desc "help"                  "h"    help-map

      :desc "Toggle side windows"   "~"    #'window-toggle-side-windows
      :desc "Find file"             "."    #'find-file
      :desc "Switch buffer"         ","    #'switch-to-buffer
      (:when (modulep! :ui workspaces)
       :desc "Switch workspace buffer" "," #'+vertico/switch-workspace-buffer
       :desc "Switch buffer"           "<" #'switch-to-buffer)
      :desc "Switch to last buffer" "`"    #'evil-switch-to-windows-last-buffer
      :desc "Resume last search"    "'"    #'vertico-repeat

      :desc "Search for symbol in project" "*" #'+default/search-project-for-symbol-at-point
      :desc "Search project"               "/" #'+default/search-project

      :desc "Find file in project"  "SPC"  #'project-find-file
      :desc "Jump to bookmark"      "RET"  #'bookmark-jump

      ;;; <leader> TAB --- workspace
      (:when (modulep! :ui workspaces)
       (:prefix-map ("TAB" . "workspace")
        :desc "Display tab bar"           "TAB" #'+workspace/display
        :desc "Switch workspace"          "."   #'+workspace/switch-to
        :desc "Switch to last workspace"  "`"   #'+workspace/other
        :desc "New workspace"             "n"   #'+workspace/new
        :desc "New named workspace"       "N"   #'+workspace/new-named
        :desc "Kill this workspace"       "d"   #'+workspace/kill
        :desc "Rename workspace"          "r"   #'+workspace/rename
        :desc "Restore last session"      "R"   #'doom/quickload-session
        :desc "Next workspace"            "]"   #'+workspace/switch-right
        :desc "Previous workspace"        "["   #'+workspace/switch-left
        :desc "Switch to 1st workspace"   "1"   #'+workspace/switch-to-0
        :desc "Switch to 2nd workspace"   "2"   #'+workspace/switch-to-1
        :desc "Switch to 3rd workspace"   "3"   #'+workspace/switch-to-2
        :desc "Switch to 4th workspace"   "4"   #'+workspace/switch-to-3
        :desc "Switch to 5th workspace"   "5"   #'+workspace/switch-to-4
        :desc "Switch to 6th workspace"   "6"   #'+workspace/switch-to-5
        :desc "Switch to 7th workspace"   "7"   #'+workspace/switch-to-6
        :desc "Switch to 8th workspace"   "8"   #'+workspace/switch-to-7
        :desc "Switch to 9th workspace"   "9"   #'+workspace/switch-to-8
        :desc "Switch to final workspace" "0"   #'+workspace/switch-to-final))

      ;;; <leader> b --- buffer
      (:prefix-map ("b" . "buffer")
       :desc "Toggle narrowing"            "-"   #'doom/toggle-narrow-buffer
       :desc "Previous buffer"             "["   #'previous-buffer
       :desc "Next buffer"                 "]"   #'next-buffer
       (:when (modulep! :ui workspaces)
        :desc "Switch workspace buffer" "b" #'+vertico/switch-workspace-buffer
        :desc "Switch buffer"           "B" #'switch-to-buffer)
       (:unless (modulep! :ui workspaces)
        :desc "Switch buffer"           "b" #'switch-to-buffer)
       :desc "Clone buffer"                "c"   #'clone-indirect-buffer
       :desc "Clone buffer other window"   "C"   #'clone-indirect-buffer-other-window
       :desc "Kill buffer"                 "d"   #'kill-current-buffer
       :desc "ibuffer"                     "i"   #'ibuffer
       :desc "Kill buffer"                 "k"   #'kill-current-buffer
       (:when (modulep! :ui workspaces)
        :desc "Kill all buffers" "K" #'+workspace/kill-all-buffers)
       (:unless (modulep! :ui workspaces)
        :desc "Kill all buffers" "K" #'doom/kill-all-buffers)
       :desc "Switch to last buffer"       "l"   #'evil-switch-to-windows-last-buffer
       :desc "Set bookmark"                "m"   #'bookmark-set
       :desc "Delete bookmark"             "M"   #'bookmark-delete
       :desc "Next buffer"                 "n"   #'next-buffer
       :desc "New empty buffer"            "N"   #'evil-buffer-new
       (:when (modulep! :ui workspaces)
        :desc "Kill other buffers" "O" #'+workspace/kill-other-buffers)
       (:unless (modulep! :ui workspaces)
        :desc "Kill other buffers" "O" #'doom/kill-other-buffers)
       :desc "Previous buffer"             "p"   #'previous-buffer
       :desc "Revert buffer"               "r"   #'revert-buffer
       :desc "Rename buffer"               "R"   #'rename-buffer
       :desc "Save buffer"                 "s"   #'basic-save-buffer
       :desc "Save all buffers"            "S"   #'evil-write-all
       :desc "Save buffer as root"         "u"   #'doom/sudo-save-buffer
       :desc "Pop up scratch buffer"       "x"   #'doom/open-scratch-buffer
       :desc "Switch to scratch buffer"    "X"   #'doom/switch-to-scratch-buffer
       :desc "Yank buffer"                 "y"   #'+default/yank-buffer-contents
       :desc "Bury buffer"                 "z"   #'bury-buffer
       :desc "Kill buried buffers"         "Z"   #'doom/kill-buried-buffers)

      ;;; <leader> c --- code
      (:prefix-map ("c" . "code")
       (:when (modulep! :tools lsp)
        :desc "LSP Execute code action" "a" #'eglot-code-actions
        :desc "LSP Rename" "r" #'eglot-rename
        :desc "Jump to symbol in current workspace" "j"   #'consult-eglot-symbols)
       :desc "Compile"                               "c"   #'compile
       :desc "Recompile"                             "C"   #'recompile
       :desc "Jump to definition"                    "d"   #'+lookup/definition
       :desc "Jump to references"                    "D"   #'+lookup/references
       :desc "Find implementations"                  "i"   #'+lookup/implementations
       :desc "Jump to documentation"                 "k"   #'+lookup/documentation
       :desc "Find type definition"                  "t"   #'+lookup/type-definition
       :desc "Delete trailing whitespace"            "w"   #'delete-trailing-whitespace
       :desc "Delete trailing newlines"              "W"   #'doom/delete-trailing-newlines
       :desc "List errors"                           "x"   #'+default/diagnostics)

      ;;; <leader> f --- file
      (:prefix-map ("f" . "file")
       :desc "Open project editorconfig"   "c"   #'editorconfig-find-current-editorconfig
       :desc "Copy this file"              "C"   #'doom/copy-this-file
       :desc "Find directory"              "d"   #'+default/dired
       :desc "Delete this file"            "D"   #'doom/delete-this-file
       :desc "Find file in emacs.d"        "e"   #'doom/find-file-in-emacsd
       :desc "Browse emacs.d"              "E"   #'doom/browse-in-emacsd
       :desc "Find file"                   "f"   #'find-file
       :desc "Find file from here"         "F"   #'+default/find-file-under-here
       :desc "Locate file"                 "l"   #'locate
       :desc "Find file in private config" "p"   #'doom/find-file-in-private-config
       :desc "Browse private config"       "P"   #'doom/open-private-config
       :desc "Recent files"                "r"   #'recentf-open-files
       :desc "Rename/move file"            "R"   #'doom/move-this-file
       :desc "Save file"                   "s"   #'basic-save-buffer
       :desc "Save file as..."             "S"   #'write-file
       :desc "Sudo find file"              "u"   #'doom/sudo-find-file
       :desc "Sudo this file"              "U"   #'doom/sudo-this-file
       :desc "Yank path at point"          "y"   #'+default/yank-path-at-point
       :desc "Yank file path from project" "Y"   #'+default/yank-buffer-path-relative-to-project)

      ;;; <leader> g --- git/version control
      (:prefix-map ("g" . "git")
       :desc "Revert file"                 "R"   #'vc-revert
       :desc "File/region history"         "t"   #'vc-region-history
       :desc "Revert hunk at point"      "r"   #'+vc-gutter/save-and-revert-hunk
       :desc "Stage hunk at point"       "s"   #'+vc-gutter/stage-hunk
       :desc "Jump to next hunk"         "]"   #'+vc-gutter/next-hunk
       :desc "Jump to previous hunk"     "["   #'+vc-gutter/previous-hunk
       :desc "Magit dispatch"            "/"   #'magit-dispatch
       :desc "Magit file dispatch"       "."   #'magit-file-dispatch
       :desc "Magit switch branch"       "b"   #'magit-branch-checkout
       :desc "Magit status"              "g"   #'magit-status
       :desc "Magit status here"         "G"   #'magit-status-here
       :desc "Magit file delete"         "D"   #'magit-file-delete
       :desc "Magit blame"               "B"   #'magit-blame-addition
       :desc "Magit clone"               "C"   #'magit-clone
       :desc "Magit fetch"               "F"   #'magit-fetch
       :desc "Magit buffer log"          "L"   #'magit-log-buffer-file
       :desc "Git stage this file"       "S"   #'magit-file-stage
       :desc "Git unstage this file"     "U"   #'magit-file-unstage
       (:prefix ("f" . "find")
        :desc "Find file"                 "f"   #'magit-find-file
        :desc "Find gitconfig file"       "g"   #'magit-find-git-config-file
        :desc "Find commit"               "c"   #'magit-show-commit)
       (:prefix ("l" . "list")
        :desc "List repositories"         "r"   #'magit-list-repositories
        :desc "List submodules"           "s"   #'magit-list-submodules)
       (:prefix ("c" . "create")
        :desc "Initialize repo"           "r"   #'magit-init
        :desc "Clone repo"                "R"   #'magit-clone
        :desc "Commit"                    "c"   #'magit-commit-create
        :desc "Fixup"                     "f"   #'magit-commit-fixup
        :desc "Branch"                    "b"   #'magit-branch-and-checkout))

      ;;; <leader> i --- insert
      (:prefix-map ("i" . "insert")
       :desc "Emoji"                         "e"   #'emoji-search
       :desc "Current file name"             "f"   #'+default/insert-file-path
       :desc "Current file path"             "F"   (cmd!! #'+default/insert-file-path t)
       :desc "Evil ex path"                  "p"   (cmd! (evil-ex "r!echo "))
       :desc "From evil register"            "r"   #'evil-show-registers
       :desc "Unicode"                       "u"   #'insert-char
       :desc "From clipboard"                "y"   #'+default/yank-pop)


      ;;; <leader> o --- open
      (:prefix-map ("o" . "open")
       :desc "Default browser"    "b"  #'browse-url-of-file
       :desc "New frame"          "f"  #'make-frame
       :desc "Select frame"       "F"  #'select-frame-by-name
       :desc "Dired"              "-"  #'dired-jump
       :desc "Toggle ghostel popup"  "t" #'+ghostel/toggle
       :desc "Open ghostel here"     "T" #'+ghostel/here)

      ;;; <leader> p --- project
      (:prefix-map ("p" . "project")
       :desc "Browse project"               "." #'+default/browse-project
       :desc "Browse other project"         ">" #'doom/browse-in-other-project
       :desc "Run cmd in project root"      "!" #'project-shell-command
       :desc "Async cmd in project root"    "&" #'project-async-shell-command
       :desc "Add new project"              "a" #'doom/add-directory-as-project
       :desc "Switch to project buffer"     "b" #'project-switch-to-buffer
       :desc "Compile in project"           "c" #'project-compile
       :desc "Remove known project"         "d" #'project-forget-project
       :desc "Discover projects in folder"  "D" #'+default/discover-projects
       :desc "Find file in project"         "f" #'project-find-file
       :desc "Find file in other project"   "F" #'doom/find-file-in-other-project
       :desc "Kill project buffers"         "k" #'project-kill-buffers
       :desc "Find sibling file"            "o" #'find-sibling-file
       :desc "Switch project"               "p" #'project-switch-project
       :desc "Save project files"           "s" #'project-save-some-buffers
       :desc "Toggle scratch buffer"        "x" #'doom/toggle-project-scratch-buffer
       :desc "Switch to scratch buffer"     "X" #'doom/switch-to-project-scratch-buffer)

      ;;; <leader> q --- quit/session
      (:prefix-map ("q" . "quit/session")
       :desc "Restart emacs server"         "d" #'+default/restart-server
       :desc "Delete frame"                 "f" #'delete-frame
       :desc "Clear current frame"          "F" #'doom/kill-all-buffers
       :desc "Kill Emacs (and daemon)"      "K" #'save-buffers-kill-emacs
       :desc "Quit Emacs"                   "q" #'save-buffers-kill-terminal
       :desc "Quit Emacs without saving"    "Q" #'evil-quit-all-with-error-code
       :desc "Quick save current session"   "s" #'doom/quicksave-session
       :desc "Restore last session"         "l" #'doom/quickload-session
       :desc "Save session to file"         "S" #'doom/save-session
       :desc "Restore session from file"    "L" #'doom/load-session
       :desc "Restart Emacs"                "r" #'doom/restart)


      ;;; <leader> s --- search
      (:prefix-map ("s" . "search")
       :desc "Search buffer"                "b" #'+default/search-buffer
       :desc "Search all open buffers"      "B" (cmd!! #'consult-line-multi 'all-buffers)
       :desc "Search current directory"     "d" #'+default/search-cwd
       :desc "Search other directory"       "D" #'+default/search-other-cwd
       :desc "Search .emacs.d"              "e" #'+default/search-emacsd
       :desc "Locate file"                  "f" #'locate
       :desc "Jump to symbol"               "i" #'imenu
       :desc "Jump to symbol in open buffers" "I" #'consult-imenu-multi
       :desc "Jump to link"                 "L" #'ffap-menu
       :desc "Jump list"                    "j" #'evil-show-jumps
       :desc "Jump to bookmark"             "m" #'bookmark-jump
       :desc "Search project"               "p" #'+default/search-project
       :desc "Search other project"         "P" #'+default/search-other-project
       :desc "Jump to mark"                 "r" #'evil-show-marks
       :desc "Search buffer"                "s" #'+default/search-buffer
       :desc "Search buffer for thing at point" "S" #'+vertico/search-symbol-at-point)

      ;;; <leader> t --- toggle
      (:prefix-map ("t" . "toggle")
       :desc "Big mode"                     "b" #'doom-big-font-mode
       :desc "Fill Column Indicator"        "c" #'global-display-fill-column-indicator-mode
       :desc "Diff Highlights (Git Gutter)" "d" #'diff-hl-mode
       :desc "Flymake"                      "f" #'flymake-mode
       :desc "Frame fullscreen"             "F" #'toggle-frame-fullscreen
       :desc "Indent style"                 "I" #'doom/toggle-indent-style
       :desc "Line numbers"                 "l" #'doom/toggle-line-numbers
       :desc "Read-only mode"               "r" #'read-only-mode
       :desc "Visible mode"                 "v" #'visible-mode
       :desc "Soft line wrapping"           "w" #'visual-line-mode))
