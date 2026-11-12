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
echo "## straight build dirs (informational)"; ls "$ROOT/.local/straight/build-31.1" | wc -l

check "*Warnings* empty" "$(ec "$WARN_EL")" '^"none"$'
check "*Messages* clean before opening files" "$(ec "$LINES_EL")" '^"none"$'
keys=$(ec "(with-current-buffer (find-file-noselect \"$TMP/proj/notes.txt\") (evil-normal-state) (mapcar (lambda (k) (cons k (commandp (key-binding (kbd k))))) '(\"SPC SPC\" \"SPC p p\" \"SPC b b\" \"SPC /\" \"SPC g g\")))")
check "leader keys are commands" "$keys" '^\(\("SPC SPC" \. t\) \("SPC p p" \. t\) \("SPC b b" \. t\) \("SPC /" \. t\) \("SPC g g" \. t\)\)$'
echo "## leader key bindings (informational)"
ec "(with-current-buffer (find-file-noselect \"$TMP/proj/notes.txt\") (mapcar (lambda (k) (cons k (key-binding (kbd k)))) '(\"SPC SPC\" \"SPC p p\" \"SPC b b\" \"SPC /\" \"SPC g g\")))"
files=$(ec "(mapcar (lambda (f) (condition-case e (with-current-buffer (find-file-noselect (expand-file-name f \"$TMP/proj/\")) (list f major-mode)) (error (list f 'ERROR e)))) '(\"Foo.java\" \"main.go\"))")
check "Java and Go modes" "$files" '^\(\("Foo.java" java-ts-mode\) \("main.go" go-ts-mode\)\)$'
check "*Messages* clean after opening files" "$(ec "$LINES_EL")" '^"none"$'
echo "## features after opening files (baseline: 375) (informational)"; ec '(length features)'

[[ $fails -eq 0 ]] || { echo "$fails check(s) failed"; exit 1; }
echo "smoke passed"
