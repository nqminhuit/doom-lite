#!/usr/bin/env bash
# Daemon smoke test via bin/lite; exits non-zero on any failed check.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LITE=$ROOT/bin/lite
ec() { timeout 120 "$LITE" client --eval "$1"; }

if "$LITE" client --eval t >/dev/null 2>&1; then echo "daemon doom-lite already live" >&2; exit 1; fi
TMP=$(mktemp -d)
trap '"$LITE" stop >/dev/null 2>&1; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/proj" && git -C "$TMP/proj" init -q
printf 'hello\n' > "$TMP/proj/notes.txt"
printf 'class Foo {}\n' > "$TMP/proj/Foo.java"
printf 'module example.com/p\n\ngo 1.22\n' > "$TMP/proj/go.mod"
printf 'package main\n\nfunc main() {}\n' > "$TMP/proj/main.go"

fails=0
# check NAME OUTPUT EXPECTED_REGEX; prints the raw output either way.
check() {
  echo "## $1"
  echo "$2"
  if [[ $2 =~ $3 ]]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

LINES_EL='(with-current-buffer "*Messages*" (let (r) (dolist (l (split-string (buffer-substring-no-properties (point-min) (point-max)) "\n")) (when (string-match-p "\\(?:[Ee]rror\\|[Ww]arning\\)" l) (push l r))) (or (nreverse r) "none")))'
WARN_EL='(if (get-buffer "*Warnings*") (with-current-buffer "*Warnings*" (buffer-substring-no-properties (point-min) (point-max))) "none")'

start=$(date +%s.%N)
"$LITE" daemon 2>"$TMP/daemon.err"
rc=$?
echo "## daemon exit=$rc wall=$(echo "$(date +%s.%N) - $start" | bc)s"
echo "## daemon stderr (errors/warnings only)"; grep -iE "error|warn" "$TMP/daemon.err" || echo "(none)"
[[ $rc -eq 0 ]] || { echo "FAIL daemon start"; exit 1; }

# A prompt in a daemon blocks every client; turn prompts into errors so checks fail instead of hang.
ec '(dolist (f (quote (y-or-n-p yes-or-no-p read-from-minibuffer read-char-choice read-multiple-choice completing-read))) (advice-add f :before (lambda (&rest a) (error "smoke: unexpected prompt: %S" (car a)))))' >/dev/null

echo "## init time (informational)"; ec '(list (emacs-init-time) (bound-and-true-p doom-init-time) gcs-done)'
echo "## features at startup (informational)"; ec '(length features)'
echo "## straight build dirs (informational)"; find "$ROOT/.local/straight/build-31.1" -mindepth 1 -maxdepth 1 | wc -l

check "*Warnings* empty" "$(ec "$WARN_EL")" '^"none"$'
check "*Messages* clean before opening files" "$(ec "$LINES_EL")" '^"none"$'
keys=$(ec "(with-current-buffer (find-file-noselect \"$TMP/proj/notes.txt\") (evil-normal-state) (mapcar (lambda (k) (cons k (commandp (key-binding (kbd k))))) '(\"SPC SPC\" \"SPC p p\" \"SPC b b\" \"SPC /\" \"SPC g g\")))")
check "leader keys are commands" "$keys" '^\(\("SPC SPC" \. t\) \("SPC p p" \. t\) \("SPC b b" \. t\) \("SPC /" \. t\) \("SPC g g" \. t\)\)$'
# Lazy: bound to Emacs/package commands that are unbound until their library loads (verified by requiring it).
LAZY_EL='(org-clock-goto org-capture-goto-target org-store-link org-clock-cancel winner-undo winner-redo ffap-other-window eglot-rename eglot-code-actions)'
UNBOUND_EL='(let (bad seen) (cl-labels ((walk (m path) (unless (memq m seen) (push m seen) (map-keymap (lambda (ev b) (let ((p (append path (list ev))) (b (if (eq (car-safe b) (quote menu-item)) (nth 2 b) (if (and (consp b) (stringp (car b))) (cdr b) b)))) (cond ((keymapp b) (walk (if (symbolp b) (symbol-function b) b) p)) ((and b (symbolp b) (not (memq b LAZYLIST)) (not (fboundp b))) (push (cons (key-description (vconcat p)) b) bad))))) m)))) (dolist (m (list help-map doom-leader-map)) (walk m nil))) (or (nreverse bad) "none"))'
UNBOUND_EL=${UNBOUND_EL/LAZYLIST/"'$LAZY_EL"}
check "commands in help-map and leader are fboundp" "$(ec "$UNBOUND_EL")" '^"none"$'
MINH_CMDS='(java/compile java/test java/test-current-method java/test-current-class java/build-lib java/build-lib-and-restart java/rebuild-services java/restart-services gis/find-modified-files gis/magit-status-at-point gis/yank-branch-name mtime/convert-selected-millis-to-date m/catcmd m/show-current-path m/run-sh-paragraph m/select-text-line m/find-file-in-project-root m/magit-copy-current-branch m/quick-calc-region)'
check "bound minh commands are fboundp at startup" "$(ec "(or (seq-remove (function fboundp) (quote $MINH_CMDS)) \"none\")")" '^"none"$'
check "text-mode has no ispell completion" "$(ec '(with-temp-buffer (text-mode) (and (memq (function ispell-completion-at-point) completion-at-point-functions) t))')" '^nil$'
echo "## leader key bindings (informational)"
ec "(with-current-buffer (find-file-noselect \"$TMP/proj/notes.txt\") (mapcar (lambda (k) (cons k (key-binding (kbd k)))) '(\"SPC SPC\" \"SPC p p\" \"SPC b b\" \"SPC /\" \"SPC g g\")))"
files=$(ec "(mapcar (lambda (f) (condition-case e (with-current-buffer (find-file-noselect (expand-file-name f \"$TMP/proj/\")) (list f major-mode)) (error (list f 'ERROR e)))) '(\"Foo.java\" \"main.go\"))")
check "Java and Go modes" "$files" '^\(\("Foo.java" java-ts-mode\) \("main.go" go-ts-mode\)\)$'
check "*Messages* clean after opening files" "$(ec "$LINES_EL")" '^"none"$'
echo "## features after opening files (baseline: 375) (informational)"; ec '(length features)'

[[ $fails -eq 0 ]] || { echo "$fails check(s) failed"; exit 1; }
echo "smoke passed"
