# FIX2

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS FIX2: <state> | next | blocked | needs user` to the conductor.

Why now: the user opened a Java file in a Maven/Gradle dir that is not under git and got `[eglot] (warning) No applicable method: project-root, nil` and `cl-no-applicable-method: No applicable method: project-root, nil`. Since P5, project.el only knows git, `.jj` and `.project` roots, so `(project-current)` is nil there, and `config/modules/minh/java/config.el` calls `(project-root (project-current))` unguarded: line 22 (`jdtls-command-contact`) and line 120 (dape `jdtls` config).

User decision: guard, don't add pom.xml/gradle root markers. When there is no project, fall back to the root eglot itself uses for the buffer (its transient project, i.e. the file's directory), so jdtls starts without error. A non-git dir the user wants as one project is registered with `SPC p a` (writes `.project`). Grep `config/` and `modules/` for any other unguarded `(project-root (project-current))` (no `t` argument) and guard those the same way. Add a unit test: the contact function returns a contact whose `-data` dir is derived from the file's directory when no project exists (temp dir, no network, jdtls not needed).

Work only in `/opt/minh/doom-lite-wt/FIX2` (branch off `origin/master`). Copy `.local` from `/opt/minh/doom-lite` (don't modify it) and run `yes y | bin/lite doom sync`. One stacea call. Force-push is denied. One PR to `master`; when ready, report it to the conductor, who reviews and merges it.
