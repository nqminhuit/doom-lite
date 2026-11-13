# FIX3

**Task**: FIX3: fixes from the user's recorded test session. **Status:** merged (PR [#17](https://github.com/nqminhuit/doom-lite/pull/17), merge `623f0f0`, 2026-11-13). **Owner:** FIX3 worker; conductor `doom-lite-conductor`. **Board:** `docs/handoff/doom-lite.md`.

## Done
- `79166ef` (fork): shellcheck flymake backend is removed on `sh-base-mode-hook` when `sh-shellcheck-program` isn't on PATH (`modules/checkers/syntax/config.el`). `+workspace--rename-tab` silences Emacs 31's "Renamed tab to" message, which `tab-bar-rename-tab` prints while tab-bar-mode is off. That message was a P6 regression; all 4 callers are fixed.
- `99b28d8` (config): `m--project-file-candidates` expands the `~`-abbreviated project root before `fd` and `mm--get-file-names`.
- `53e7e9a` (config): `jdtls-command-contact` adds `-javaagent` only when `+java--lombok-jar` exists. Otherwise it warns once (`+java--lombok-warned`).
- Tests: `tests/unit/syntax-tests.el`, plus additions to workspaces-, minh- and java-tests. `tests/run.sh` and `tests/smoke.sh` pass.

## Gaps
- The board still shows FIX3 as "implementing" with no PR.
- Worktree `/opt/minh/doom-lite-wt/FIX3`, the local branch and remote branch `fix3-recorded-test-issues` still exist.

## Context for continuing
- jdtls root cause: `lombok-version` 1.18.46 jar was missing from `~/.m2`, and the JVM exited 1. The user installed the jar. Verified in an isolated daemon (`--daemon=fix3`, not `doom-lite`) on a scratch copy of gis: jdtls stays up and `gd` opens `GisLog.java:10`.
- Item 4 non-regressions, left alone:
  - which-key "SPC : m/find-file" is `SPC SPC` with no `:desc` (same as linux-config).
  - `+<localleader>` is the same upstream.
  - `[]` is the user's prot-modeline flymake segment.
  - `SPC f C-g` handling matches upstream (concluded from the source; upstream wasn't run).

## Next steps
1. Conductor: set FIX3 to merged on the board. Remove the worktree (`git worktree remove /opt/minh/doom-lite-wt/FIX3`), then delete the local and remote `fix3-recorded-test-issues` branches.
2. Optional, config: add `:desc` to `"<SPC>" #'m/find-file` (`config/modules/minh/keybindings/config.el:111`) if the user wants a label.
3. Cutover remains deferred until the user asks.

## Watch out
- In a frameless daemon, gis's `.dir-locals.el` (unsafe `compile-command`, `projectile-*`) blocks on the safety prompt. Trap prompts as `tests/smoke.sh` does before visiting gis files.
- `pkill -f "daemon=fix3"` kills your own shell, because the pattern appears in its command line. Use `pgrep -f "^emacs --init-directory …"`.
- jdtls init options write metadata files at the project root, so test on a copy, not `~/projects/gis`.
