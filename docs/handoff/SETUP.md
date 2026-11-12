# SETUP

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS SETUP: <state> | next | blocked | needs user` to the conductor.

Why now: P1 needs a populated submodule, a config inside the fork, and a baseline. Approved by the user: there is no `/opt/minh/linux-config-lite`.

Do, in your own worktree `/opt/minh/doom-lite-wt/SETUP` (branch off `master`; never switch branches in `/opt/minh/doom-lite`), one draft PR to `master`:
1. `git submodule update --init sources/doom+` (at `f054be8f`; don't edit it).
2. Copy `/opt/minh/linux-config/configs/dotfiles/emacs/doom-emacs` (master `3ced698a`) to `config/`. Resolve symlinks. Don't touch the live tree or `~/.config`.
3. Adapt `doom-lite-plan.md`: config lives in `config/`, `DOOMDIR` default there, one PR per phase, a worktree per worker, P1 keeps `docs/fleet` and `docs/handoff`, cutover copies `config/` back, S1 note goes to P11.
4. First sync and baseline (EMACSDIR/DOOMDIR exported by hand, never live dirs), saved next to the plan.
