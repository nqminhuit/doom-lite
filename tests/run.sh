#!/usr/bin/env bash
# Runs every test; keeps going after a failure and exits non-zero if any failed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

failed=()
run() {
  echo "== $*"
  "$@" || failed+=("$*")
}

run tests/smoke-guard-test.sh
for f in tests/unit/*-tests.el; do
  run emacs --batch -Q -l "$f" -f ert-run-tests-batch-and-exit
done

if [[ ${#failed[@]} -gt 0 ]]; then
  printf 'FAILED: %s\n' "${failed[@]}"
  exit 1
fi
echo "all tests passed"
