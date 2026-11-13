# CUT1

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS CUT1: <state> | next | blocked | needs user` to the conductor.

Goal: the linux-config PR from `doom-lite-plan.md` § Cutover → Changes → "linux-config PR" (base `master` of `/opt/minh/linux-config`).

## Handoff
- **Task**: CUT1, linux-config PR for the doom-lite cutover. Status: done (merged). Owner: conductor `doom-lite-conductor`; no tracker. Link: [linux-config#160](https://github.com/nqminhuit/linux-config/pull/160).
- **Done**:
  - #160 merged as `2fabc329`. Worktree `/opt/minh/linux-config-wt/CUT1` and branch `doom-lite-cutover` (local and remote) removed.
  - The main linux-config checkout is clean at `2fabc329`; the user already dropped the uncommitted `config.el` edit and pulled.
- **Gaps**: none.
- **Context for continuing**:
  - `configs/dotfiles/emacs/doom-lite/` is the fork's `config/` plus `gemit-backend 'gemini`, which is also in `doom-emacs/config.el`. `custom.el` is gitignored in both; `LOMBOK_VERSION` reads from `doom-lite/`.
  - `lazarus.sh`:
    - `__doom_pair` and `_doom_use`: refuse before any change, stop `eterm` only if it answers, always symlink.
    - `__doom_prepare_config_dir`: a real `~/.config/doom` may hold only links and `custom.el`; `custom.el` is copied where missing, and the script refuses if an existing copy differs.
    - `_install_doom`: checks every refusal before it moves, removes or clones anything. A real upstream checkout is renamed to `~/.config/doom-emacs` with both links to the upstream pair. An absent `~/.config/emacs` gets the lite pair. If one link exists, the other matches it; existing links never flip. `lazarus doom` clones the fork over https.
  - Verified with `tests/run.sh`: lint, 17 new bats tests in `tests/lazarus.bats`, and `tests/elisp/doom-lite-tests.el`.
- **Next steps**:
  1. CUT1 needs nothing more. CUT2 (fork PR #20) is merged too. CUT3 continues at Cutover Step 2 (stop `eterm`, `mv ~/.config/emacs ~/.config/doom-emacs`), which waits for the user's OK in the conductor's CUT3 session.
- **Watch out**:
  - Run Cutover Step 3 by hand, as the plan says, or let `lazarus.sh doom` do it. On this machine the script refuses if `~/.config/doom` holds anything other than links and `custom.el`.
  - `bats` and `shellcheck` were installed via apt on this machine during CUT1.
