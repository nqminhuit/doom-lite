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

## Conductor handoff
- Restart: `lazarus fleet up doom-lite` from `/opt/minh/doom-lite`; sessions resume their conversations. The main checkout stays on `master`; commit the board there only, then push.
- Sessions: P2 (implementing; plan in its handoff). P1 removed.
- Waiting on user: remove worktree `/opt/minh/doom-lite-wt/P1` and local branch `p1-vendor-modules`? P2 no longer needs them.
- Next: when P2's PR is merged, start P3 with a brief in `docs/handoff/P3.md` (same shape as `P2.md`), and so on per the board. P11 gets its own plan pass first.
- Worker tips (from handoffs): copy `.local` from the previous worktree, then `bin/lite doom sync` (use `--force` if it dies on a prompt); copy tree-sitter grammars after a fresh sync; `bin/` needs `git add -f`; shellcheck via podman.

## Board

| Key | State | PR | Blocker | Next |
|---|---|---|---|---|
| SETUP | merged (`7e15dfb`); session removed; worktree and local branch deleted by SETUP itself | [#1](https://github.com/nqminhuit/doom-lite/pull/1) | – | – |
| S1 | done, session removed (findings and decisions in `docs/handoff/S1.md`) | – | – | user chose A: P11 uses the fallback backend (clone at pin, load-path, autoloads, no package.el). ghostel: download-only (`ghostel-module-auto-install` `'download`, `ghostel-module-directory` outside the package tree; zig compile unsupported). Findings go into P11 after SETUP merges |
| P1 | merged (`f3c34b1`) after user's pass | [#2](https://github.com/nqminhuit/doom-lite/pull/2) | – session removed, remote branch deleted; worktree `/opt/minh/doom-lite-wt/P1` (and its local branch) no longer needed by P2: user to confirm removal. Kept from plan: `static/`, `set-debug-var!`; `SPC h d` manual commands have no targets until P10 |
| P2 | implementing, fork stacea call; `.local` synced, baseline tests pass (worktree `/opt/minh/doom-lite-wt/P2`, branch `p2-popup-display-buffer-alist`) | – | – | after `fleet up`: fork stacea call (old-behavior tests, shim, delete `ui/popup`), then config call. user confirmed: `popup +defaults` rules stay dropped (help, compilation, Warnings, Backtrace open normally); PR notes it |
| P3 | waiting on P2 | – | P2 merged | – |
| P4 | waiting on P3 | – | P3 merged | – |
| P5 | waiting on P4 | – | P4 merged | – |
| P6 | waiting on P5 | – | P5 merged | – |
| P7 | waiting on P6 | – | P6 merged | – |
| P8 | waiting on P7 | – | P7 merged | – |
| P9 | waiting on P8 | – | P8 merged | – |
| P10 | waiting on P9 | – | P9 merged | – |
| P11 | waiting on P10 | – | P10 merged; S1 findings; own plan pass | – |
