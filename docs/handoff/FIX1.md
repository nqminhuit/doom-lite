# FIX1

**Task**: FIX1, two bugs the user hit: the startup `ansi-color-inverse` face error and `SPC p a` refusing existing project roots. Status: **merged** ([PR #15](https://github.com/nqminhuit/doom-lite/pull/15), merge `aae032a` on `master`). Owner: conductor `doom-lite-conductor`. There is no external ticket; the board is `docs/handoff/doom-lite.md`.

## Done
- Commit `6063d5b` on branch `fix1-face-and-add-project`, merged into `master` via #15. The main checkout is already at `aae032a`.
- `config/modules/minh/dashboard/config.el`: today's date in the calendar uses `'(:inverse-video t)`.
- `lisp/lib/projects.el`:
  - `doom/add-directory-as-project`: the exclusion check runs first. An existing root (git/`.jj`/`.project`) is remembered without creating a file. A plain dir gets `.project` and is remembered. A dir inside another project errors.
  - `doom--project-excluded-p` now runs `(require 'project)`.
- Tests: `startup-buffer-faces-are-defined` (fails on the old face), plus 4 `projects/add-directory-*` tests.

## Gaps
- The board row for FIX1 still says "started". It should say merged.
- The worktree `/opt/minh/doom-lite-wt/FIX1` and the local and remote branch `fix1-face-and-add-project` still exist.

## Context for continuing
- Verification: `tests/run.sh` passes. I confirmed the new face test fails against the old `config.el`.
- The old "Directory is already a project" refusal was removed on purpose (user decision).

## Next steps
1. Conductor: mark FIX1 merged on the board.
2. Remove the worktree: `git worktree remove /opt/minh/doom-lite-wt/FIX1`, then delete the branch.
3. Ask the user to restart Emacs in the main checkout. Then confirm that no `Invalid face reference` message appears and that `SPC p a` on `/opt/minh/linux-config` remembers the project.
4. Cutover is still deferred by the user.

## Watch out
- A fresh worktree with a copied `.local` makes `bin/lite doom sync </dev/null` crash on the "packages must be rebuilt (y or n)" prompt. Use `yes y | bin/lite doom sync`.
- `project-list-exclude` is void under `emacs --batch -Q` until `project` is loaded.
- Force-push is denied. Only the conductor merges.

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS FIX1: <state> | next | blocked | needs user` to the conductor.

Why now: all phases are merged; the user hit two bugs using the fork in the main checkout (2026-11-13). Fix both in one small PR:
1. Startup logs `Invalid face reference: ansi-color-inverse` many times. `config/modules/minh/dashboard/config.el:62` highlights today in the calendar with that face, which exists only once `ansi-color` is loaded (upstream loaded it early). Use a face that always exists (e.g. `'(:inverse-video t)`), keep the look, and make the startup test fail if the face is undefined.
2. `SPC p a` (`doom/add-directory-as-project`, `lisp/lib/projects.el`) refuses a dir that is already a project root (`/opt/minh/linux-config`). User decision: a git/`.jj`/`.project` root is simply remembered (as `projectile-add-known-project` did); a plain dir gets a `.project` file and is remembered; a dir inside another project still errors; an excluded dir still errors. Update `tests/unit/projects-tests.el` (old cases that encode the refusal change: say so in the PR).

Work only in `/opt/minh/doom-lite-wt/FIX1` (branch off `origin/master`). Copy `.local` from `/opt/minh/doom-lite` (the main checkout, on the new backend) and run `bin/lite doom sync </dev/null`; don't modify the main checkout. One stacea call. Force-push is denied. One PR to `master`; when ready, report it to the conductor, who reviews and merges it.
