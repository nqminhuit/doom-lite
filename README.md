# doom-lite

A personal hard fork of Doom Emacs for Emacs 31. Only the modules I use are vendored under `modules/`, and the upstream tie is cut: there is no `doom upgrade`, updates come from `git pull`.

Until cutover, run everything through `bin/lite` (it pins `EMACSDIR`/`DOOMDIR` to this checkout and refuses the live config): `bin/lite doom sync`, `bin/lite emacs`, `bin/lite daemon`, `bin/lite client`, `bin/lite stop`.

Tests: `tests/run.sh` (wrapper guards and unit tests) and `tests/smoke.sh` (starts a daemon and checks startup, keybindings and Java/Go modes).

See `doom-lite-plan.md` for the plan. Licensed under the terms in `LICENSE`.
