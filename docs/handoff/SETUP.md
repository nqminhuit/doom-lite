# SETUP

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS SETUP: <state> | next | blocked | needs user` to the conductor.

Why now: P1 needs a populated submodule, a config inside the fork, and a baseline. Approved by the user: there is no `/opt/minh/linux-config-lite`.

Do, in your own worktree `/opt/minh/doom-lite-wt/SETUP` (branch off `master`; never switch branches in `/opt/minh/doom-lite`), one draft PR to `master`:
1. `git submodule update --init sources/doom+` (at `f054be8f`; don't edit it).
2. Copy `/opt/minh/linux-config/configs/dotfiles/emacs/doom-emacs` (master `3ced698a`) to `config/`. Resolve symlinks. Don't touch the live tree or `~/.config`.
3. Adapt `doom-lite-plan.md`: config lives in `config/`, `DOOMDIR` default there, one PR per phase, a worktree per worker, P1 keeps `docs/fleet` and `docs/handoff`, cutover copies `config/` back, S1 note goes to P11.
4. First sync and baseline (EMACSDIR/DOOMDIR exported by hand, never live dirs), saved next to the plan.

## Handoff
- **Task**: SETUP (config in the fork, submodule, first sync, baseline). Done, merged. Owner: SETUP session; set `doom-lite`, conductor `doom-lite-conductor`. [PR #1](https://github.com/nqminhuit/doom-lite/pull/1).
- **Done**:
  - Merged to `master` as `7e15dfb`:
    - `config/`: 18 files from linux-config commit `3ced698a`
    - `doom-lite-plan.md` adapted, with S1 folded into P11 and the ERT port moved into P1
    - `doom-lite-baseline.md`
  - Worktree `/opt/minh/doom-lite-wt/SETUP` and branch `setup-config-and-baseline` deleted, local and remote. Nothing is unpushed.
- **Gaps**: the board's SETUP row still asks whether to remove the worktree; it is already gone.
- **Context for continuing**:
  - The baseline (`doom-lite-baseline.md`) has the exact sync, doctor and smoke commands. Its `smoke-baseline.sh` is the model for P1's `tests/smoke.sh`.
  - Isolation was verified with before/after mtime snapshots of `~/.local/share/doom`, `~/.config/emacs/.local` and the socket dir.
  - A fork sync never writes `~/.local/share/doom/profiles.el`; the bootloader is only active when `EMACSDIR` is `~/.config/emacs` or `~/.emacs.d`.
- **Next steps**:
  1. P1 is underway in `/opt/minh/doom-lite-wt/P1` (see the board).
- **Watch out**:
  - **Tree-sitter grammars:** a fresh `.local` has none, and opening Go or Java in a daemon then blocks every client on "Install now?". After the first sync, copy `~/.config/emacs/.local/etc/tree-sitter/*.so` into `.local/etc/tree-sitter/`.
  - **`.gitignore`:** `/modules/*/` ignores vendored module dirs until P1 un-ignores them.
  - **Public repo:** the fork is public and now contains `config/`. The user accepted this; keep secrets out of `config/`.
  - **Doctor notices:** `doom doctor` reports "two private configs" (`~/.config/doom` and `config/`). That is a false alarm, since `doom-user-dir` is `config/`.
