# FIX2

- **Task**: FIX2 — jdtls `No applicable method: project-root, nil` when opening Java in a non-git Maven/Gradle dir. Status: merged. Conductor: `doom-lite-conductor` (set `doom-lite`, board `docs/handoff/doom-lite.md`). PR: https://github.com/nqminhuit/doom-lite/pull/16

## Done
- PR #16 merged into `master` (`9c9574f`, commit `02eba97`), branch `fix2-jdtls-no-project`.
- `config/modules/minh/java/config.el`: new top-level `+java--project` returns `(project-current)` or eglot's transient project `(transient . default-directory)`. `jdtls-command-contact` takes `(&optional interactive project)`. When eglot passes a project (it does if the arity allows 2 args, eglot.el:1583), it uses that, otherwise the helper. The dape `jdtls` fn binds the project once for `project-root` and `project-name`.
- `tests/unit/java-tests.el`: two tests. With no project, `-data` is the md5 of the file's dir. An explicit project's root wins.

## Gaps
- The board (`docs/handoff/doom-lite.md`) still lists FIX2 as the active session until the conductor updates it.
- The worktree `/opt/minh/doom-lite-wt/FIX2` and the local and remote branch `fix2-jdtls-no-project` still exist.

## Context for continuing
- User decision: guard only, no pom.xml/gradle root markers. A non-git dir meant as one project is registered with `SPC p a` (writes `.project`).
- No other `(project-current)` call without `t` in `config/` or `modules/` is unguarded.
- Verified with `tests/run.sh` (all pass) in the worktree and by the conductor's review.

## Next steps
1. Conductor: mark FIX2 merged on the board, then remove the worktree and both branches.
2. User, interactive only: open a Java file in a non-git Maven dir and confirm jdtls starts and dape attaches.

## Watch out
- The dape fn is not unit tested, because it needs a live jdtls.
- With no project, each directory gets its own jdtls workspace (`lsp-cache/<md5 of dir>`), so files in sibling packages of an unregistered Maven tree start separate servers. Register the root with `SPC p a` to avoid that.
