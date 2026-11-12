# doom-lite baseline (SETUP, 2026-11-12)

Taken before P1, in the worktree `/opt/minh/doom-lite-wt/SETUP` on branch `setup-config-and-baseline`: fork `master` at `bdc7b85`, `sources/doom+` at `f054be8f`, `config/` from linux-config `3ced698a`. GNU Emacs 31.1. `EMACSDIR`/`DOOMDIR` exported by hand (no `bin/lite` yet). Later phases compare against this.

## Summary

| Metric | Value |
|---|---|
| `doom sync` (fresh `.local`) | exit 0, 3m21s wall |
| Package build dirs (`ls .local/straight/build-31.1 \| wc -l`) | 79 (the live install also has 79) |
| `doom doctor` | 1 warning (zig not found, ghostel; harmless), 37 modules, 90 packages declared. Plus three expected notices: non-standard install location; another Emacs config at `~/.config/emacs`; "two private configs" (`~/.config/doom/` and `config/`). That last one is a false alarm here: `doom-user-dir` is `config/` in the smoke output |
| Init time, daemon, 2nd start (warm) | `emacs-init-time` 0.166 s, `doom-init-time` 0.191 s; 1st start 0.156 / 0.181 s (both after native-comp from sync) |
| `features` after smoke | 375 |
| `*Warnings*` / `*Messages*` errors | none / none |
| `SPC SPC` · `SPC p p` · `SPC b b` · `SPC /` · `SPC g g` | `m/find-file` · `projectile-switch-project` · `+vertico/switch-workspace-buffer` · `+default/search-project` · `gis/magit-status-or-status` |
| `Foo.java` / `main.go` | `java-ts-mode` / `go-ts-mode`, no errors |

Isolation: mtimes of `~/.local/share/doom`, `~/.config/emacs/.local` and `/run/user/$UID/emacs` were snapshotted before and after; nothing changed except the socket directory's own mtime (named sockets `doom-lite-setup`/`doom-lite-probe` created and removed; live `server` socket untouched). SETUP made no change to linux-config; `configs/claude/settings.json` there showed as modified during the run, from another session, not SETUP.

Found during SETUP: a fresh `.local` has no tree-sitter grammars, and opening a Go/Java file then blocks the daemon on a y-or-n-p (see Workspace in `doom-lite-plan.md`). The grammars were copied from `~/.config/emacs/.local/etc/tree-sitter/` (doxygen, go, java, json, yaml) before these numbers were taken.

## Commands

```sh
WT=/opt/minh/doom-lite-wt/SETUP
export EMACSDIR=$WT/ DOOMDIR=$WT/config/
unset DOOMLOCALDIR DOOMPROFILE
bin/doom sync --force </dev/null
mkdir -p .local/etc/tree-sitter && cp -p ~/.config/emacs/.local/etc/tree-sitter/*.so .local/etc/tree-sitter/
bin/doom doctor </dev/null
ls .local/straight/build-31.1 | wc -l
bash smoke-baseline.sh "$WT"   # script below; run twice, numbers from the 2nd run
```

### smoke-baseline.sh (model for P1's `tests/smoke.sh`)

```bash
#!/usr/bin/env bash
# Baseline smoke checks for the SETUP worktree; the model for P1's tests/smoke.sh.
set -uo pipefail
WT=${1:?worktree}
export EMACSDIR="$WT/" DOOMDIR="$WT/config/"
unset DOOMLOCALDIR DOOMPROFILE
SOCK=doom-lite-setup
ec() { timeout 120 emacsclient -s "$SOCK" --eval "$1"; }

if emacsclient -s "$SOCK" --eval t >/dev/null 2>&1; then echo "socket $SOCK already live" >&2; exit 1; fi
TMP=$(mktemp -d)
trap 'emacsclient -s "$SOCK" --eval "(kill-emacs)" >/dev/null 2>&1; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/proj" && git -C "$TMP/proj" init -q
printf 'hello\n' > "$TMP/proj/notes.txt"
printf 'class Foo {}\n' > "$TMP/proj/Foo.java"
printf 'module example.com/p\n\ngo 1.22\n' > "$TMP/proj/go.mod"
printf 'package main\n\nfunc main() {}\n' > "$TMP/proj/main.go"

start=$(date +%s.%N)
emacs --init-directory "$EMACSDIR" --daemon="$SOCK" 2>"$TMP/daemon.err"
echo "## daemon exit=$? wall=$(echo "$(date +%s.%N) - $start" | bc)s"
echo "## daemon stderr (errors/warnings only)"; grep -iE "error|warn" "$TMP/daemon.err" || echo "(none)"

# A prompt in a daemon blocks every client; turn prompts into errors so checks fail instead of hang.
ec '(dolist (f (quote (y-or-n-p yes-or-no-p read-from-minibuffer read-char-choice read-multiple-choice completing-read))) (advice-add f :before (lambda (&rest a) (error "smoke: unexpected prompt: %S" (car a)))))' >/dev/null
echo "## init time"; ec '(list (emacs-init-time) (bound-and-true-p doom-init-time) gcs-done)'
echo "## user-emacs-directory / doom-user-dir / doom-local-dir"; ec '(list user-emacs-directory doom-user-dir doom-local-dir)'
echo "## *Warnings*"; ec '(if (get-buffer "*Warnings*") (with-current-buffer "*Warnings*" (buffer-substring-no-properties (point-min) (point-max))) "none")'
echo "## *Messages* error/warning lines"; ec '(with-current-buffer "*Messages*" (let (r) (dolist (l (split-string (buffer-substring-no-properties (point-min) (point-max)) "\n")) (when (string-match-p "\\(?:[Ee]rror\\|[Ww]arning\\)" l) (push l r))) (or (nreverse r) "none")))'
echo "## leader keys in a file buffer, normal state"
ec "(with-current-buffer (find-file-noselect \"$TMP/proj/notes.txt\") (evil-normal-state) (mapcar (lambda (k) (cons k (key-binding (kbd k)))) '(\"SPC SPC\" \"SPC p p\" \"SPC b b\" \"SPC /\" \"SPC g g\")))"
echo "## Java and Go files"
ec "(mapcar (lambda (f) (condition-case e (with-current-buffer (find-file-noselect (expand-file-name f \"$TMP/proj/\")) (list f major-mode)) (error (list f 'ERROR e)))) '(\"Foo.java\" \"main.go\"))"
echo "## *Messages* error/warning lines after opening files"; ec '(with-current-buffer "*Messages*" (let (r) (dolist (l (split-string (buffer-substring-no-properties (point-min) (point-max)) "\n")) (when (string-match-p "\\(?:[Ee]rror\\|[Ww]arning\\)" l) (push l r))) (or (nreverse r) "none")))'
echo "## features loaded"; ec '(length features)'
```

## Smoke output (2nd run)

```
## daemon exit=0 wall=.852286631s
## daemon stderr (errors/warnings only)
(none)
## init time
("0.166447 seconds" 0.190690391 2)
## user-emacs-directory / doom-user-dir / doom-local-dir
("/opt/minh/doom-lite-wt/SETUP/.local/cache/"
 "/opt/minh/doom-lite-wt/SETUP/config/" "/opt/minh/doom-lite-wt/SETUP/.local/")
## *Warnings*
"none"
## *Messages* error/warning lines
"none"
## leader keys in a file buffer, normal state
(("SPC SPC" . m/find-file) ("SPC p p" . projectile-switch-project)
 ("SPC b b" . +vertico/switch-workspace-buffer)
 ("SPC /" . +default/search-project) ("SPC g g" . gis/magit-status-or-status))
## Java and Go files
(("Foo.java" java-ts-mode) ("main.go" go-ts-mode))
## *Messages* error/warning lines after opening files
"none"
## features loaded
375
```

## doom doctor output

```
The doctor will see you now...

> Checking your Emacs version...
> Checking for Doom's prerequisites...
> Checking for Emacs config conflicts...
  ! Doom is installed in a non-standard location
    The standard locations are ~/.config/emacs or ~/.emacs.d. Emacs will
    fail to load Doom if it is not explicitly told where to look for
    it. In Emacs 29+, this is possible with the --init-directory option:
    
      $ emacs --init-directory '/opt/minh/doom-lite-wt/SETUP/'
    
    However, Emacs 27-28 users have no choice but to move Doom to a
    standard location.
    
    Chemacs users may ignore this warning, however.
  ! Found another Emacs config: ~/.config/emacs (directory)
    Having multiple Emacs configs may prevent Doom from loading
    properly. Emacs will load the first it finds and ignore the rest. If
    Doom isn't starting up correctly (e.g. you get a vanilla splash
    screen), make sure that only one of these exist.
    
    Chemacs users may ignore this warning.
> Checking for missing Emacs features...
> Checking for fonts...
> Checking for private config conflicts...
  ! Detected two private configs, in ~/.config/doom/ and /opt/minh/doom-lite-wt/SETUP/config/
    The second directory will be ignored, as it has lower precedence.
> Checking for common environmental issues...
> Checking for stale elc files...
> Checking for problematic git global settings...
> Checking Doom Emacs...
  ✓ Initialized Doom Emacs 2.2.4
  ✓ Detected 37 modules
  ✓ Detected 90 packages
  > Checking Doom core for irregularities...
    Found Symbols Nerd Font Mono
  > Checking for stale elc files in your DOOMDIR...
  > Checking your enabled modules...
    > :term ghostel
      ! Couldn't find zig. Pre-built binaries cover most platforms; only needed if you want to compile the ghostel module from source via M-x ghostel-module-compile

There is 1 warning!
exit 0
```
