# CUT2

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS CUT2: <state> | next | blocked | needs user` to the conductor.

Goal: the fork PR from `doom-lite-plan.md` § Cutover → Changes → "Fork PR" (base `master` of `nqminhuit/doom-lite`). The cutover started on 2026-11-13. CUT1 (linux-config PR #160, merged as `2fabc329`) added `configs/dotfiles/emacs/doom-lite/` and `tests/elisp/doom-lite-tests.el` there, so the fork's `config/` and `tests/unit/minh-tests.el` can go now.

Decided:
- Work in a worktree `/opt/minh/doom-lite-wt/CUT2` (copy `.local` in if tests need it); the main checkout stays on `master`.
- `tests/smoke.sh` defaults `DOOMDIR` to `/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite` and never touches the `eterm` daemon.
- Don't touch the live install or `~/.config/*`; the live steps belong to CUT3, which starts after this merges.
- The conductor reviews and merges the PR.


## Handoff
- **Task**: CUT2, the fork side of the cutover (`doom-lite-plan.md` § Cutover → Changes → "Fork PR"). Status: done. Conductor: `doom-lite-conductor`. There is no tracker.

**Done**
- [#20](https://github.com/nqminhuit/doom-lite/pull/20) is merged as `25bb8877`. The worktree and the `cut2-fork-cutover` branch (local and remote) are removed, and nothing is unpushed.

**Gaps**
- None.

**Context for continuing**
- Removed: `bin/lite`, `tests/lite-test.sh`, `config/` and `tests/unit/minh-tests.el`. The config and its ERT suite (`tests/elisp/doom-lite-tests.el`) now live only in linux-config.
- `tests/smoke.sh` runs its own daemon on the socket `doom-smoke` and never touches `eterm`.
  - It sets `EMACSDIR` from its own location and `DOOMDIR` from `$DOOM_LITE_CONFIG`, whose default is `/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite`. It never inherits `DOOMDIR`.
  - It refuses to start when that dir has no `init.el`, when `.local` is unsynced, or when `doom-smoke` is already running. The kill trap is installed only after those checks.
  - `tests/smoke-guard-test.sh` covers the refusals using stub `emacs`/`emacsclient`.
- `tests/config-dir.el` (`tcd-config-dir`) is the only place the unit tests look up the config. Eleven tests use it, and they error rather than skip when the config is missing.
- How it was verified: `tests/run.sh`, `tests/smoke.sh` and shellcheck all passed against a copy of linux-config `master`.

**Next steps**
1. CUT3: the live steps 2–8 (see `CUT3.md`). Step 2 is waiting for the user's OK.
2. After CUT3 step 6, run the fork's `tests/run.sh` once more against the real linux-config path. It is pulled now (`2fabc329`).

**Watch out**
- A `.local` copied from another checkout keeps that checkout's paths in `.local/etc/@`, and a plain `doom sync` writes them back. Remove `.local/etc/@` and sync again.
- The stray untracked `config/custom.el` in the main doom-lite checkout was deleted on the user's instruction.
- Config edits now go to linux-config `doom-lite/`. The fork has no config.
