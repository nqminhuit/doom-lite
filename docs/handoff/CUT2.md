# CUT2

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS CUT2: <state> | next | blocked | needs user` to the conductor.

Goal: the fork PR from `doom-lite-plan.md` § Cutover → Changes → "Fork PR" (base `master` of `nqminhuit/doom-lite`). The cutover started on 2026-11-13. CUT1 (linux-config PR #160, merged as `2fabc329`) added `configs/dotfiles/emacs/doom-lite/` and `tests/elisp/doom-lite-tests.el` there, so the fork's `config/` and `tests/unit/minh-tests.el` can go now.

Decided:
- Work in a worktree `/opt/minh/doom-lite-wt/CUT2` (copy `.local` in if tests need it); the main checkout stays on `master`.
- `tests/smoke.sh` defaults `DOOMDIR` to `/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite` and never touches the `eterm` daemon.
- Don't touch the live install or `~/.config/*`; the live steps belong to CUT3, which starts after this merges.
- The conductor reviews and merges the PR.
