# CUT3

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS CUT3: <state> | next | blocked | needs user` to the conductor after each step.

Goal: run the live cutover, `doom-lite-plan.md` § Cutover → Steps 2–8 (step 1 is done: linux-config #160 merged as `2fabc329`, fork #20 merged as `25bb8877`). No code changes and no PR.

Decided:
- The user is present in your pane. Before each step, show its exact commands and wait for the user's OK; run its check afterwards and stop on any failure. Rollback is `./lazarus.sh doom-use doom` (§ Rollback).
- Step 0: make sure `/opt/minh/linux-config` is on `master`, has no local changes and is pulled to include `2fabc329`, so `configs/dotfiles/emacs/doom-lite/` exists. If it isn't, ask the user to run `git checkout -- configs/dotfiles/emacs/doom-emacs/config.el && git pull` there.
- Before step 2, save `doom doctor` output as the baseline for steps 3–4.
- `tests/smoke.sh` never touches the `eterm` daemon; `restartEmacs` is the user's call.
