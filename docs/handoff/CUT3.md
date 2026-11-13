# CUT3

- **Task**: CUT3, the live cutover (`doom-lite-plan.md` § Cutover, steps 2–8). Status: done 2026-11-13. Owner: `doom-lite-conductor`, set `doom-lite`, board `docs/handoff/doom-lite.md`. No tracker.

## Done
- Steps 2–8 were run with the user's OK before each step; no code changes and no PR.
- Upstream Doom lives at `~/.config/doom-emacs`. The fork is cloned to `~/.config/doom-lite` at `46ce6ed`.
- `~/.config/emacs` and `~/.config/doom` are symlinks to the doom-lite pair. `custom.el` was moved into linux-config's `doom-emacs/` and copied to `doom-lite/`, where it is gitignored.
- Smoke passed, and the user checked the interactive list and both directions of the rollback drill.
- The `lazarus doom` re-run wrote both `.local/.lazarus-doom-installed` markers.
- The user regenerated both env files from their own terminal; the `eterm` daemon runs doom-lite with a clean environment.
- The untracked `config/custom.el` in this workspace was deleted.

## Gaps
- Plan § Cutover does not yet carry what the run found; CUT4 adds it (see `docs/handoff/CUT4.md`).

## Context for continuing
- The `doom doctor` baseline had 2 warnings: a stale env file and no zig. After cutover there are 0, with 35 modules and 66 packages.
- The rollback is `lazarus doom-use doom`, then `restartEmacs`.

## Next steps
1. CUT4: a docs-only PR in worktree `/opt/minh/doom-lite-wt/CUT4` off `master`, per `docs/handoff/CUT4.md`.
2. Optional: the user re-checks eglot in a Go project, since gopls is now v0.24.0 on go1.27.4.
3. Remove the CUT3 session once the user OKs it.

## Watch out
- Running `doom version` while `~/.config/emacs` is absent creates `~/.emacs.d`, which shadows Doom.
- The first `lazarus doom` run is not a no-op: it runs `doom install --force`, `sudo apt-get` and `go install @latest`.
- Never run `doom sync --env` from a Claude Code shell: the env file captures `CLAUDE_*` vars, including the messaging token.
