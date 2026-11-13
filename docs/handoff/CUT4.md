# CUT4

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS CUT4: <state> | next | blocked | needs user` to the conductor.

Goal: docs-only PR to `nqminhuit/doom-lite` `master` that adds to `doom-lite-plan.md` § Cutover what the live run (CUT3, done 2026-11-13) found:
1. Step 2: `doom version` run while `~/.config/emacs` is absent makes Emacs create `~/.emacs.d` (eln-cache only); move it aside before `restartEmacs`.
2. Step 8 is not a no-op on its first run: with no `.local/.lazarus-doom-installed` markers, `doom install --force` runs on both installs; it also runs `sudo apt-get` and `go install …@latest` (gopls jumped to v0.24.0), so the user runs it in their own terminal.
3. Generate env files (`doom sync --env`, `doom env`) from the user's own terminal, never from a Claude Code shell: they capture `CLAUDE_*` vars including `CLAUDE_CODE_MESSAGING_TOKEN`.

Decided: work in a worktree `/opt/minh/doom-lite-wt/CUT4`; no code changes; the conductor reviews and merges. Details in `docs/handoff/CUT3.md` and the board's CUT3 row.
