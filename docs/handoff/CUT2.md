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
Done: fork PR #20 merged as `25bb8877`. Worktree `/opt/minh/doom-lite-wt/CUT2` and branch `cut2-fork-cutover` (local and remote) removed.

What landed:
- Removed `bin/lite`, `tests/lite-test.sh`, `config/` and `tests/unit/minh-tests.el`. The config and its ERT suite (`tests/elisp/doom-lite-tests.el`) now live only in linux-config.
- `tests/smoke.sh` sets `EMACSDIR` from its own location and `DOOMDIR` from `$DOOM_LITE_CONFIG`, defaulting to `/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite`; it never inherits `DOOMDIR`. It runs on the socket `doom-smoke` and never touches `eterm`. It refuses when `DOOMDIR` has no `init.el`, when `.local` is unsynced or when `doom-smoke` is already live, and it installs its kill trap only after those checks. `tests/smoke-guard-test.sh` covers the refusals with stubs and replaces `lite-test.sh` in `tests/run.sh`.
- `tests/config-dir.el` (`tcd-config-dir`) is the one place unit tests resolve the config. Eleven tests use it: abbrev, java, startup, keybinds, modulep-targets, autodef, help, core-trims, no-spellcheck, minh-autoload and workspace-keys. They error, rather than skip, when the config is missing.
- README and the plan's Workspace and Verification sections describe working with an explicit `EMACSDIR`/`DOOMDIR` and the linux-config dependency. Historical phase sections, `doom-lite-baseline.md` and `docs/handoff/` are unchanged.

Gotcha: a `.local` copied from another checkout keeps that checkout's paths in `.local/etc/@`, and a plain `doom sync` re-dumps them. Remove `.local/etc/@` and sync again. This is noted in the plan's Workspace section.

Open for others:
- The fork's `tests/run.sh` and `tests/smoke.sh` fail until the main linux-config checkout is pulled. It was 5 commits behind, with an uncommitted `doom-emacs/config.el`, so `doom-lite/` was not on disk yet. CUT1's note applies: drop that edit before pulling.
- The main doom-lite checkout has a stray untracked `config/custom.el`, which is all that is left of `config/`. Remove it or ignore it. Step 3 of the cutover copies `custom.el` from `~/.config/doom`, not from here.
- Next is CUT3 (live Steps 2–8).
