# FIX1

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS FIX1: <state> | next | blocked | needs user` to the conductor.

Why now: all phases are merged; the user hit two bugs using the fork in the main checkout (2026-11-13). Fix both in one small PR:
1. Startup logs `Invalid face reference: ansi-color-inverse` many times. `config/modules/minh/dashboard/config.el:62` highlights today in the calendar with that face, which exists only once `ansi-color` is loaded (upstream loaded it early). Use a face that always exists (e.g. `'(:inverse-video t)`), keep the look, and make the startup test fail if the face is undefined.
2. `SPC p a` (`doom/add-directory-as-project`, `lisp/lib/projects.el`) refuses a dir that is already a project root (`/opt/minh/linux-config`). User decision: a git/`.jj`/`.project` root is simply remembered (as `projectile-add-known-project` did); a plain dir gets a `.project` file and is remembered; a dir inside another project still errors; an excluded dir still errors. Update `tests/unit/projects-tests.el` (old cases that encode the refusal change: say so in the PR).

Work only in `/opt/minh/doom-lite-wt/FIX1` (branch off `origin/master`). Copy `.local` from `/opt/minh/doom-lite` (the main checkout, on the new backend) and run `bin/lite doom sync </dev/null`; don't modify the main checkout. One stacea call. Force-push is denied. One PR to `master`; when ready, report it to the conductor, who reviews and merges it.
