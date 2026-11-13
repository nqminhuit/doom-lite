#!/usr/bin/env bash
# Checks the tests/smoke.sh refusals with stub emacs/emacsclient; never starts Emacs.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

root=$TMP/root
mkdir -p "$root/tests" "$TMP/stubs" "$TMP/cfg" "$TMP/noinit"
cp "$ROOT/tests/smoke.sh" "$root/tests/smoke.sh"
touch "$TMP/cfg/init.el"
# The stub emacsclient logs every call to $CALLS and answers "live" only when STUB_LIVE=1.
# shellcheck disable=SC2016  # the stubs must expand their own variables
printf '#!/bin/sh\necho "$*" >>"$CALLS"\n[ "$STUB_LIVE" = 1 ]\n' >"$TMP/stubs/emacsclient"
# shellcheck disable=SC2016
printf '#!/bin/sh\necho "emacs $*" >>"$CALLS"\nexit 9\n' >"$TMP/stubs/emacs"
chmod +x "$TMP/stubs/emacsclient" "$TMP/stubs/emacs"
export PATH=$TMP/stubs:$PATH CALLS=$TMP/calls STUB_LIVE=0
: >"$CALLS"

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

DOOM_LITE_CONFIG=$TMP/noinit check "DOOMDIR without init.el refused" 1 "no init.el" "$root/tests/smoke.sh"
DOOM_LITE_CONFIG=$TMP/cfg check "unsynced .local refused" 1 "bin/doom sync" "$root/tests/smoke.sh"
mkdir -p "$root/.local/etc/@"
touch "$root/.local/etc/@/init.31.1.el"
STUB_LIVE=1 DOOM_LITE_CONFIG=$TMP/cfg check "live doom-smoke refused" 1 "already live" "$root/tests/smoke.sh"
if grep -q 'kill-emacs' "$CALLS"; then
  echo "FAIL a refused run called (kill-emacs)"
  fails=$((fails + 1))
else
  echo "ok   a refused run never kills the daemon"
fi
if grep -q '^emacs ' "$CALLS"; then
  echo "FAIL a refused run started Emacs"
  fails=$((fails + 1))
fi

[[ $fails -eq 0 ]] || { echo "$fails failure(s)"; exit 1; }
echo "all passed"
