# CUT0

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS CUT0: <state> | next | blocked | needs user` to the conductor.

Why now: the user wants the Cutover section of `doom-lite-plan.md` rewritten to a symlink design before any cutover happens. Doc-only PR; the cutover itself stays deferred until the user asks. Change nothing outside the plan, and touch nothing live.

Design (user-approved, 2026-11-13):
- Two installs side by side: `~/.config/doom-emacs` (today's upstream checkout, renamed, its `.local` kept) and `~/.config/doom-lite` (a clone of the fork). `~/.config/emacs` is a symlink to the active one.
- Two configs in linux-config: `configs/dotfiles/emacs/doom-emacs/` stays frozen for upstream Doom; the fork's `config/` is added as `configs/dotfiles/emacs/doom-lite/`. `~/.config/doom` is a symlink to the matching config. A switch always flips both links.
- A small switch command in `lazarus.sh` (e.g. `lazarus doom-use lite|doom`): flips both links, stops a running Emacs daemon (same socket name), refuses if a target is missing, and prints the active pair. With bats tests.
- Rollback = run the switch command; no revert, no porting. Config edits made in one config don't carry to the other (say so).
- Verified facts to state: each install keeps its own `.local`; `~/.local/share/doom/profiles.el` is only read with `--profile` (unused); Doom's scripts resolve the `~/.config/emacs` symlink.
- Keep from today's Cutover: first `doom sync` in `doom-lite` uses the new backend; the four grammars (markdown, markdown-inline, gomod, gowork); delete `bin/lite` and switch `tests/smoke.sh` to plain `bin/doom`/`emacs`/test socket (check whether its refusals still matter with the symlinks); carry live config edits made after `3ced698a` into `doom-lite/` (diff first); `lazarus.sh` `_install_doom` clones both repos into their dirs and creates the links; update its bats tests and the Doom paragraph in linux-config's `CLAUDE.md`.
- Add a short "Rollback" subsection and a step order with a check after each step (e.g. switch to doom-lite, run smoke; switch back, confirm upstream starts).

Work in `/opt/minh/doom-lite-wt/CUT0` (branch off `origin/master`); no `.local` needed. Edit only the Cutover section (and any one-line references to it elsewhere in the plan). Force-push is denied. One PR to `master`; report it to the conductor, who reviews and merges it.
