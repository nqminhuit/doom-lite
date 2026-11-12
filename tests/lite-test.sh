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

[[ $fails -eq 0 ]] || { echo "$fails failure(s)"; exit 1; }
echo "all passed"
