# CUT1

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS CUT1: <state> | next | blocked | needs user` to the conductor.

Goal: the linux-config PR from `doom-lite-plan.md` § Cutover → Changes → "linux-config PR" (base `master` of `/opt/minh/linux-config`). User asked to start the cutover on 2026-11-13; this PR comes first.

Decided:
- Work in a worktree `/opt/minh/linux-config-wt/CUT1`; leave the main linux-config checkout alone.
- The uncommitted change in the main checkout's `configs/dotfiles/emacs/doom-emacs/config.el` goes into `doom-emacs/` in this PR (user chose this) and is carried into `doom-lite/`. Copy `doom-lite/` from the fork's `config/` at `origin/master`.
- Do not touch the live install, `~/.config/doom`, or the `eterm` daemon; Steps 2–8 are CUT3's.
- The conductor reviews and merges the PR. CUT2 (fork PR) waits for that merge.

## Handoff (2026-11-13)
Done: linux-config PR #160 merged as `2fabc329`. Worktree `/opt/minh/linux-config-wt/CUT1` and branch `doom-lite-cutover` (local and remote) removed.

What landed:
- `configs/dotfiles/emacs/doom-lite/` copied from the fork's `config/` at `origin/master`, plus the live `gemit-backend 'gemini` edit, which also went into `doom-emacs/config.el`. `custom.el` is gitignored in both config dirs. `LOMBOK_VERSION` now reads from `doom-lite/`.
- `./lazarus.sh doom-use lite|doom`: refuses before changing anything; stops the `eterm` daemon only if it answers; always uses symlinks; listed in the help text.
- `_install_doom` handles each starting state:
  - Every refusal is checked before anything is moved, removed or cloned.
  - A real upstream checkout at `~/.config/emacs` is renamed to `~/.config/doom-emacs`, and both links then point at the upstream pair.
  - When `~/.config/emacs` is absent, both links point at the lite pair.
  - When one link exists, the other is made to match it; existing links never flip.
  - A real `~/.config/doom` is accepted only if it holds just links and `custom.el`. `custom.el` is copied into both configs where missing, and the script refuses if an existing copy differs; anything else is refused with a message.
  - Each install is installed and synced with its own `EMACSDIR`/`DOOMDIR`.
- 17 bats tests in `tests/lazarus.bats`; `tests/elisp/doom-lite-tests.el` added and wired into `tests/run.sh`; `CLAUDE.md` Doom paragraph and a `mutils.sh` comment updated.

Side effects: `bats` and `shellcheck` installed via apt on this machine.

Open for others: the user removes the uncommitted `config.el` edit in the main linux-config checkout before pulling. Next is CUT2 (fork PR), then CUT3 (live Steps 2–8).
