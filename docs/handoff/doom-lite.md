# doom-lite fleet board

Set `doom-lite`, conductor `doom-lite-conductor`. Executes `doom-lite-plan.md`. No Jira: keys are the plan's phase IDs.

## Decisions (approved 2026-11-12)
- No `/opt/minh/linux-config-lite`. SETUP copies `configs/dotfiles/emacs/doom-emacs` from linux-config `master` (`3ced698a`) into the fork as `config/`; `bin/lite` defaults `DOOMDIR` to it. At cutover `config/` goes back to linux-config `master`.
- One branch and one PR per phase in `nqminhuit/doom-lite`, base `master`; fork and config edits are two stacea calls in that PR.
- Each worker works in its own git worktree of the fork (`/opt/minh/doom-lite-wt/<KEY>`); the main checkout stays on `master` for the board. Each worktree needs its own first `doom sync`.
- P1 deletes `docs/` except `docs/fleet/` and `docs/handoff/`.
- S1 findings go to P11 (the plan's "P10" there is a typo).
- The user's interactive pass gates every merge.
- `doom-lite` stays public with `config/` in it.
- P1 ports linux-config `tests/elisp/minh-tests.el` to `tests/unit/minh-tests.el`, pointed at `config/`.
- P11 uses the fallback backend (clone at pin, load-path, autoloads, no package.el); ghostel module is download-only.

## Board

| Key | State | PR | Blocker | Next |
|---|---|---|---|---|
| SETUP | draft PR ready for user pass (head `21d654c`; S1 and ERT-port folded into plan) | [#1](https://github.com/nqminhuit/doom-lite/pull/1) | – | user review, interactive pass, merge |
| S1 | done, session removed (findings and decisions in `docs/handoff/S1.md`) | – | – | user chose A: P11 uses the fallback backend (clone at pin, load-path, autoloads, no package.el). ghostel: download-only (`ghostel-module-auto-install` `'download`, `ghostel-module-directory` outside the package tree; zig compile unsupported). Findings go into P11 after SETUP merges |
| P1 | waiting on SETUP | – | SETUP PR merged into `master` | brief must say: edit `.gitignore` (`/modules/*/` ignores vendored modules; only `!/modules/doom/` is excepted) |
| P2 | waiting on P1 | – | P1 merged; S1 finished | – |
| P3 | waiting on P2 | – | P2 merged | – |
| P4 | waiting on P3 | – | P3 merged | – |
| P5 | waiting on P4 | – | P4 merged | – |
| P6 | waiting on P5 | – | P5 merged | – |
| P7 | waiting on P6 | – | P6 merged | – |
| P8 | waiting on P7 | – | P7 merged | – |
| P9 | waiting on P8 | – | P8 merged | – |
| P10 | waiting on P9 | – | P9 merged | – |
| P11 | waiting on P10 | – | P10 merged; S1 findings; own plan pass | – |
