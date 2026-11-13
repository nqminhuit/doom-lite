# doom-lite fleet board

Set `doom-lite`, conductor `doom-lite-conductor`. Executes `doom-lite-plan.md`. No Jira: keys are the plan's phase IDs.

## Decisions (approved 2026-11-12)
- No `/opt/minh/linux-config-lite`. SETUP copies `configs/dotfiles/emacs/doom-emacs` from linux-config `master` (`3ced698a`) into the fork as `config/`; `bin/lite` defaults `DOOMDIR` to it. At cutover `config/` goes back to linux-config `master`.
- One branch and one PR per phase in `nqminhuit/doom-lite`, base `master`; fork and config edits are two stacea calls in that PR.
- Each worker works in its own git worktree of the fork (`/opt/minh/doom-lite-wt/<KEY>`); the main checkout stays on `master` for the board. Each worktree needs its own first `doom sync`.
- P1 deletes `docs/` except `docs/fleet/` and `docs/handoff/`.
- S1 findings go to P11 (the plan's "P10" there is a typo).
- From P2 on (user, 2026-11-13): the conductor reviews each phase PR (`gh pr diff`, re-run `tests/run.sh`, check the phase's greps) and merges it when it passes; no user interactive pass before merge. The conductor lists in its report what only an interactive check would catch.
- `doom-lite` stays public with `config/` in it.
- P1 ports linux-config `tests/elisp/minh-tests.el` to `tests/unit/minh-tests.el`, pointed at `config/`.
- transient stays built-in (Emacs 0.13.3; user confirmed 2026-11-13), not pinned in `.local`.
- P11 uses the fallback backend (clone at pin, load-path, autoloads, no package.el); ghostel module is download-only.

## Conductor handoff
- Restart: `lazarus fleet up doom-lite` from `/opt/minh/doom-lite`; sessions resume their conversations. The main checkout stays on `master`; commit the board there only, then push.
- Sessions: P10 (implementing). P1–P9 removed. After a phase merges, remove its session with `fleet remove --yes` (user approved this for every phase, 2026-11-13). Worktrees need no approval either: once the next phase reports the old worktree free, remove it and its local and remote branch.
- Waiting on user: nothing. Main checkout `/opt/minh/doom-lite` is synced (user tries the fork there; ghostel module downloaded). The user may sync the main checkout to try the fork there (`bin/lite doom sync`; the conductor already copied all 9 grammars into its `.local/etc/tree-sitter`); its `.local` is gitignored and does not affect `master`.
- Next: when P2's PR is merged, start P3 with a brief in `docs/handoff/P3.md` (same shape as `P2.md`), and so on per the board. P11 gets its own plan pass first.
- Worker tips (from handoffs): copy `.local` from the previous worktree, then `bin/lite doom sync` (use `--force` if it dies on a prompt); copy tree-sitter grammars after a fresh sync; `bin/` needs `git add -f`.

## Board

| Key | State | PR | Blocker | Next |
|---|---|---|---|---|
| SETUP | merged (`7e15dfb`); session removed; worktree and local branch deleted by SETUP itself | [#1](https://github.com/nqminhuit/doom-lite/pull/1) | – | – |
| S1 | done, session removed (findings and decisions in `docs/handoff/S1.md`) | – | – | user chose A: P11 uses the fallback backend (clone at pin, load-path, autoloads, no package.el). ghostel: download-only (`ghostel-module-auto-install` `'download`, `ghostel-module-directory` outside the package tree; zig compile unsupported). Findings go into P11 after SETUP merges |
| P1 | merged (`f3c34b1`) after user's pass | [#2](https://github.com/nqminhuit/doom-lite/pull/2) | – session removed, remote branch deleted; worktree and local branch removed. Kept from plan: `static/`, `set-debug-var!`; `SPC h d` manual commands have no targets until P10 |
| P2 | merged (`cc3f8d8`) by the conductor after review, on the user's go-ahead; session, worktree and branches removed | [#3](https://github.com/nqminhuit/doom-lite/pull/3) | – | after `fleet up`: fork stacea call (old-behavior tests, shim, delete `ui/popup`), then config call. user confirmed: `popup +defaults` rules stay dropped (help, compilation, Warnings, Backtrace open normally); gis rule keeps `:quit nil` (ESC never closes `*gis: *`), so P2 corrects the plan's check; PR notes both |
| P3 | merged (`bddd342`) by the conductor after review; session, worktree and branches removed | [#4](https://github.com/nqminhuit/doom-lite/pull/4) | – | Interactive-only: startup buffer look/centring in GUI and client frames; `q` in normal state records a macro instead of quitting |
| P4 | merged (`6eb80c8`) by the conductor after review; session, worktree and branches removed | [#5](https://github.com/nqminhuit/doom-lite/pull/5) | – | Deliberate losses: `SPC s o/O/k/K/t/T`, `:lookup`/`:dash`, help `O`, `K` online fallback. History: 3 commits with a wrong co-author trailer and one test-before-code commit, merged as-is (user). Leftover docs: lookup README mentions `set-docsets!`, lsp README `+booster` (P10) |
| P5 | merged (`75f3058`) by the conductor after review; session, worktree and branches removed | [#6](https://github.com/nqminhuit/doom-lite/pull/6) | – | Accepted changes: `SPC p` keys `C R T g r e i` dropped; `SPC p D` prompts for a dir; projects remembered only by project commands, not by visiting files; java/js root markers gone. Baseline package count is stale (85 now) |
| P6 | merged (`70822b0`) by the conductor after review; session, worktree and branches removed | [#7](https://github.com/nqminhuit/doom-lite/pull/7) | – | Accepted changes: no buffer isolation per tab, `SPC b b` project-scoped, persistence commands gone (user), `SPC TAB R` restores the desktop session, killing a workspace keeps its buffers. User checked `M-1..9` in a live ghostel terminal: works (module downloaded in the main checkout; P11 moves it out of the package dir) |
| P7 | merged (`bcd3bfc`) by the conductor after review; session, worktree and branches removed | [#8](https://github.com/nqminhuit/doom-lite/pull/8) | – | Accepted changes: no `( \| )` space balancing or multiline-brace collapse on backspace; per-language pair rules gone. Unchecked: pairing in a real `M-:`/`SPC ;`/`:` minibuffer. One commit with a wrong co-author trailer, merged as-is (as for P4) |
| P8 | merged (`a4fd32e`) by the conductor after review; session, worktree and branches removed | [#9](https://github.com/nqminhuit/doom-lite/pull/9) | – | Binding snapshot identical before/after (3712 lines). Dropped unused `kbd!`, `define-leader-key!`, `map! :mode`. Unchecked: SPC in a live ghostel buffer, which-key popup look |
| P9 | merged (`bab7a71`) by the conductor after review; session, worktree and branches removed | [#10](https://github.com/nqminhuit/doom-lite/pull/10) | – | 19 packages dropped (63 left); yaml-mode and go-gen-test kept. Changes: `gc` is a built-in evil operator (no `c` text object); jumps use evil's jump list; `SPC g t` is `vc-region-history`; `.jsonc`, `.md`, `README.md`, `go.mod`, `go.work` open in ts modes. Accepted losses: go/json localleader commands, markdown-mode editing and preview. Live install lacks markdown, markdown-inline, gomod and gowork grammars (Cutover note). Unchecked: `gcc`/visual `gc` in a live frame, markdown-ts-mode look |
| P10 | implementing, task 3/4 (tasks 1 `bin/lite` guard and 2 doom-docs/`SPC h d` done) (worktree `/opt/minh/doom-lite-wt/P10`, branch `p10-core-trims`) | – | – | Dropped keys: help `h H n rd E dx dM`, `:help!` bang; `SPC h d m` opens the module README (or dired) Added by user: remove spellcheck (jinx config, ispell capf, corfu advice); delete leader/help bindings to commands from non-vendored modules; add missing `;;;###autoload` cookies in `config/modules/minh/*/autoload.el`. shellcheck stays required but not run (podman denied in P10) |
| P11 | waiting on P10 | – | P10 merged; S1 findings; own plan pass | – |
