# CUT4

- **Task**: CUT4, add the CUT3 live-run findings to `doom-lite-plan.md` § Cutover. Status: done 2026-11-13. Owner: `doom-lite-conductor`, set `doom-lite`, board `docs/handoff/doom-lite.md`. No tracker.

## Done
- [#21](https://github.com/nqminhuit/doom-lite/pull/21) was merged into `master` as `0638b7ca` (commit `ba1399a`). It is docs-only and touches only `doom-lite-plan.md`.
- Step 2: if `~/.config/emacs` is absent, `doom version` creates `~/.emacs.d` (only an `eln-cache`). Move it aside before `restartEmacs`.
- Step 4: the user runs `doom sync --env` from their own terminal.
- Step 8: the first run is not a no-op. With no `.local/.lazarus-doom-installed` markers, it runs `doom install --force` on both installs, `sudo apt-get` and `go install …@latest` (gopls went to v0.24.0). The user runs it, and the second run is a no-op.
- A new env-files note after the steps: generate env files only from the user's own terminal, never from a Claude Code shell, because they capture `CLAUDE_*` vars, including `CLAUDE_CODE_MESSAGING_TOKEN`.
- The worktree `/opt/minh/doom-lite-wt/CUT4` and the branch `docs/cut4-cutover-findings` (local and remote) were removed.

## Gaps
- None. The plan now matches what CUT3 found.

## Context for continuing
- No code changed and there were no tests to run. The conductor reviewed the PR.

- The conductor committed this handoff and the board in `01d792e`. The cutover (CUT1–CUT4) is complete, and nothing is open or unpushed.

## Next steps
1. Optional (user): re-check eglot in a Go project, because gopls is now v0.24.0.

## Watch out
- Generate env files only from the user's own terminal (see Plan § Cutover).
