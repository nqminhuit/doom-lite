#!/usr/bin/env bash
# Checks the bin/lite guards with a fake HOME; never starts Emacs.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME/.config/emacs/bin" "$HOME/.config/doom"
touch "$HOME/.config/doom/init.el"
cp "$ROOT/bin/lite" "$HOME/.config/emacs/bin/lite"

fails=0
# check NAME EXPECTED_CODE STDERR_SUBSTRING CMD...
check() {
  local name=$1 code=$2 want=$3 err rc
  shift 3
  err=$("$@" 2>&1 >/dev/null </dev/null)
  rc=$?
  if [[ $rc -eq $code && $err == *"$want"* ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name (exit $rc, want $code; stderr: $err)"
    fails=$((fails + 1))
  fi
}

mkdir -p "$TMP/cfg" "$TMP/noinit"
touch "$TMP/cfg/init.el"
ln -s "$HOME/.config/doom" "$TMP/link"
lc=/opt/minh/linux-config/nonexistent

check "live EMACSDIR refused" 1 "live Emacs dir" "$HOME/.config/emacs/bin/lite" doom
DOOM_LITE_CONFIG=$HOME/.config/doom check "live DOOMDIR refused" 1 "live Doom config" "$ROOT/bin/lite" doom
DOOM_LITE_CONFIG=$TMP/link check "symlink to live DOOMDIR refused" 1 "live Doom config" "$ROOT/bin/lite" doom
DOOM_LITE_CONFIG=$lc check "linux-config refused" 1 "linux-config" "$ROOT/bin/lite" doom
[[ ! -e $lc ]] || { echo "FAIL linux-config path was created"; fails=$((fails + 1)); }
DOOM_LITE_CONFIG=$TMP/noinit check "missing init.el refused" 1 "no init.el" "$ROOT/bin/lite" doom
DOOM_LITE_CONFIG=$TMP/cfg check "valid config, unknown subcommand" 2 "usage" "$ROOT/bin/lite" bogus

# Sync guard: fake checkout with stub binaries first on PATH; real Emacs is never started.
wt=$TMP/wt
mkdir -p "$wt/bin" "$wt/config" "$TMP/stubs"
cp "$ROOT/bin/lite" "$wt/bin/lite"
touch "$wt/config/init.el"
printf '#!/bin/sh\nexit 7\n' >"$wt/bin/doom"
printf '#!/bin/sh\nexit 7\n' >"$TMP/stubs/emacs"
printf '#!/bin/sh\nexit 1\n' >"$TMP/stubs/emacsclient"
chmod +x "$wt/bin/doom" "$TMP/stubs/emacs" "$TMP/stubs/emacsclient"
PATH=$TMP/stubs:$PATH

for sub in emacs daemon client; do
  check "unsynced $sub refused" 1 "bin/lite doom sync" "$wt/bin/lite" "$sub"
done
check "unsynced doom not refused" 7 "" "$wt/bin/lite" doom
mkdir -p "$wt/.local/etc/@"
touch "$wt/.local/etc/@/init.31.1.el"
check "synced emacs runs" 7 "" "$wt/bin/lite" emacs
check "synced daemon runs" 7 "" "$wt/bin/lite" daemon

[[ $fails -eq 0 ]] || { echo "$fails failure(s)"; exit 1; }
echo "all passed"
