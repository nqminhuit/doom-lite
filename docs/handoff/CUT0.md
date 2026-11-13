# CUT0

- **Task**: CUT0: rewrite the plan's Cutover section for the symlink design (doc-only). Status: done. PR #19 is merged. Owner: CUT0 worker, under conductor `doom-lite-conductor` (board `docs/handoff/doom-lite.md`). https://github.com/nqminhuit/doom-lite/pull/19

## Done
- PR #19 (branch `cut0-symlink-cutover`, merged into `master`). It rewrites `doom-lite-plan.md` § Cutover:
  - layout table, verified facts, `lazarus.sh doom-use lite|doom` spec and bats tests;
  - Rollback subsection, two-PR change list (linux-config first, then fork), 8 steps each with a check.
- It also fixes the stale one-line references in Context, P1 (config ERT suite) and the P11 migration note.

## Gaps
- Board row CUT0 still says "started"; the conductor needs to mark it merged.
- Worktree `/opt/minh/doom-lite-wt/CUT0` and its branch are still present and can be removed.

## Context for continuing
- Nothing was executed: the live install, `~/.config/doom` and linux-config are untouched.
- The decisions in the PR body are for the user to confirm before the cutover:
  - the fork's `config/` and `tests/unit/minh-tests.el` are deleted after cutover;
  - `custom.el` is gitignored in both config dirs;
  - `doom-use` always creates symlinks, even when `IS_PERSONAL=false`.
- Facts found:
  - `~/.config/doom` is a real dir: links, a real `custom.el`, dangling `cli.el`/`snippets`.
  - Daemon socket is `eterm` (`functions/commons.sh`).
  - `__doom_backup` follows `~/.config/emacs`.
  - linux-config has no `_install_doom` bats tests yet.
  - Upstream `.local` lacks the markdown, markdown-inline, gomod and gowork grammars; `/opt/minh/doom-lite/.local` has all nine.

## Next steps
1. Conductor: mark CUT0 merged on the board and remove the CUT0 worktree.
2. When the user asks for the cutover, follow Plan § Cutover → Changes: linux-config PR first (`doom-lite/` config, `doom-use`, `_install_doom`, bats, `CLAUDE.md`), then the fork PR, then Steps 2–8 with the user present.

## Watch out
- linux-config has an uncommitted change to `configs/dotfiles/emacs/doom-emacs/config.el`. The carry-over diff must use the working tree, not only `master`.
- Step 3 (upstream starting from the renamed `~/.config/doom-emacs`) is unverified; the fallback is `doom sync` without `-u`.
- Never touch the `eterm` daemon from tests. Force-push is denied.
