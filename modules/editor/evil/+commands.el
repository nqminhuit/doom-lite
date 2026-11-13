;;; editor/evil/+commands.el -*- lexical-binding: t; -*-

;;
;;; Custom commands
;; Editing
(evil-ex-define-cmd "al[ign]"      #'+evil:align)
(evil-ex-define-cmd "ral[ign]"     #'+evil:align-right)
(evil-ex-define-cmd "na[rrow]"     #'+evil:narrow-buffer)
(evil-ex-define-cmd "retab"        #'+evil:retab)
(evil-ex-define-cmd "rev[erse]"    #'+evil:reverse-lines)
(evil-ex-define-cmd "ldiff"        #'evil-quick-diff)

;;; External resources
(evil-ex-define-cmd "h[elp]"      #'+evil:help)

(evil-ex-define-cmd "pad"         #'+evil:open-scratch-buffer)

;;; Dealing with buffers
(evil-ex-define-cmd "kill"         #'kill-current-buffer)
(evil-ex-define-cmd "killa[ll]"    #'+evil:kill-all-buffers)
(evil-ex-define-cmd "killm[atch]"  #'+evil:kill-matching-buffers)
(evil-ex-define-cmd "killo[ther]"  #'doom/kill-other-buffers)
(evil-ex-define-cmd "killb[uried]" #'doom/kill-buried-buffers)
(evil-ex-define-cmd "msg"          #'view-echo-area-messages)

;;; Project navigation
(evil-ex-define-cmd "a"           #'find-sibling-file)
(evil-ex-define-cmd "cd"          #'+evil:cd)
(evil-ex-define-cmd "pwd"         #'+evil:pwd)

(evil-ex-define-cmd "pg[rep]"  #'+vertico:project-search)
(evil-ex-define-cmd "pdg[rep]" #'+vertico:project-search-from-cwd)

;;; Project tools
(evil-ex-define-cmd "com[pile]"   #'+evil:compile)
(evil-ex-define-cmd "make"        #'+evil:make)
(evil-ex-define-cmd "mk"          #'+evil:make) ; convenience alias
(evil-ex-define-cmd "er[rors]"    #'+default/diagnostics)

;;; File operations
(evil-ex-define-cmd "cp"          #'+evil:copy-this-file)
(evil-ex-define-cmd "mv"          #'+evil:move-this-file)
(evil-ex-define-cmd "rm"          #'+evil:delete-this-file)

;;; Sessions/tabs
(evil-ex-define-cmd "sl[oad]"     #'doom/quickload-session)
(evil-ex-define-cmd "ss[ave]"     #'doom/quicksave-session)
(evil-ex-define-cmd "tabc[lose]"  #'+workspace:delete)
(evil-ex-define-cmd "tabclear"    #'doom/kill-all-buffers)
(evil-ex-define-cmd "tabf[irst]"  #'+workspace/switch-to-0)
(evil-ex-define-cmd "tabl[ast]"   #'+workspace/switch-to-final)
(evil-ex-define-cmd "tabn[ew]"    #'+workspace:new)
(evil-ex-define-cmd "tabnext"     #'+workspace:switch-next)
(evil-ex-define-cmd "tabprev"     #'+workspace:switch-previous)
(evil-ex-define-cmd "tabr[ename]" #'+workspace:rename)
(evil-ex-define-cmd "tabs"        #'+workspace/display)

;;; Org-mode
(evil-ex-define-cmd "cap[ture]"   #'org-capture)  ; TODO: better Ex support
