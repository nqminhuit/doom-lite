# CUT1

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS CUT1: <state> | next | blocked | needs user` to the conductor.

Goal: the linux-config PR from `doom-lite-plan.md` § Cutover → Changes → "linux-config PR" (base `master` of `/opt/minh/linux-config`). User asked to start the cutover on 2026-11-13; this PR comes first.

Decided:
- Work in a worktree `/opt/minh/linux-config-wt/CUT1`; leave the main linux-config checkout alone.
- The uncommitted change in the main checkout's `configs/dotfiles/emacs/doom-emacs/config.el` goes into `doom-emacs/` in this PR (user chose this) and is carried into `doom-lite/`. Copy `doom-lite/` from the fork's `config/` at `origin/master`.
- Do not touch the live install, `~/.config/doom`, or the `eterm` daemon; Steps 2–8 are CUT3's.
- The conductor reviews and merges the PR. CUT2 (fork PR) waits for that merge.
