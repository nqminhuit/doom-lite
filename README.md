# doom-lite

A personal hard fork of Doom Emacs for Emacs 31. Only the modules I use are vendored under `modules/`, and the upstream tie is cut: there is no `doom upgrade`, updates come from `git pull`.

The config lives in linux-config, in `configs/dotfiles/emacs/doom-lite/` (default path `/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite`). The active install is chosen by `lazarus.sh doom-use lite|doom` in linux-config. Work in a worktree runs with explicit paths: `EMACSDIR=$PWD/ DOOMDIR=<config> bin/doom sync` and `emacs --init-directory "$PWD"`.

Tests: `tests/run.sh` (smoke-test guards and unit tests) and `tests/smoke.sh` (starts a daemon on the socket `doom-smoke` and checks startup, keybindings and Java/Go modes). Both need a linux-config checkout, located through `$DOOM_LITE_CONFIG` (default `/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite`); the config tests fail when it is missing.

See `doom-lite-plan.md` for the plan. Licensed under the terms in `LICENSE`.
