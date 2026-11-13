# FIX4

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS FIX4: <state> | next | blocked | needs user` to the conductor.

Why now: the user wants `SPC SPC` labelled in which-key. `config/modules/minh/keybindings/config.el:111` binds `"<SPC>" #'m/find-file` without `:desc`, so which-key shows the raw function name. Add `:desc "Find file in project"` to that binding, matching the style of its neighbours. Add a test that the leader's `SPC` entry has that which-key label (the keybinds tests show how labels are checked).

Tiny change: no stacea needed, do it directly. Work in `/opt/minh/doom-lite-wt/FIX4` (branch off `origin/master`); `tests/run.sh` must pass (no sync needed unless the test needs one; copy `.local` from `/opt/minh/doom-lite` if so, without modifying it). Force-push is denied. One PR to `master`; report it to the conductor, who reviews and merges it.
