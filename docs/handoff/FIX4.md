# FIX4

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS FIX4: <state> | next | blocked | needs user` to the conductor.

Goal: which-key shows a label for `SPC SPC` instead of the raw `m/find-file`, with a test for the leader `SPC` label.

## Handoff
- **Task**: FIX4, label `SPC SPC` as "Find file in project". Status: merged. Owner: FIX4 session, under `doom-lite-conductor`. PR: https://github.com/nqminhuit/doom-lite/pull/18
- **Done**:
  - PR #18 merged into `master` (merge `81eb962`, commit `4bad3f6`), from branch `fix4-spc-spc-label`.
  - `config/modules/minh/keybindings/config.el`: the leader `"<SPC>"` binding now has `:desc "Find file in project"`.
  - `tests/unit/keybinds-tests.el`: new test `keybinds/config-leader-spc-label`.
- **Gaps**:
  - The board row in `docs/handoff/doom-lite.md` still says "started", and this file is still in the repo. The conductor updates the board and removes this file, the same way it handled FIX3.
  - The worktree `/opt/minh/doom-lite-wt/FIX4` and the branch `fix4-spc-spc-label` (local and remote) still exist.
- **Context for continuing**:
  - `kbt--config-leader-form` reads the config file as data and returns its top-level `(:leader ...)` section. The test applies that section to a fresh `doom-leader-map` and checks the label with `kbt--label`. Use the same approach for future label tests on the real config, so tests don't touch `global-map`.
  - How it was verified: the test fails without the `:desc` and passes with it, and the whole `tests/run.sh` suite passes. Evil comes from `.local`. Without `.local`, the keybinds tests skip quietly, so copy it into a new worktree first.
- **Next steps**:
  1. Conductor: mark FIX4 merged on the board, delete this file, and remove the worktree and branch.
  2. Nothing left to do for FIX4. Next candidates are the areas the board lists as untested: ghostel, `SPC TAB`, `SPC ;`/`:`, Java outside git.
- **Watch out**: Force-push is denied. `.local` in the worktree is a copy, so leave the original in `/opt/minh/doom-lite` alone.
