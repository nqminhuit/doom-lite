# doom-lite

A personal hard fork of Doom Emacs for Emacs 31. Only the modules I use are vendored under `modules/`, and the upstream tie is cut: there is no `doom upgrade`, updates come from `git pull`.

## Requirements

- Emacs 31.
- Git and internet access to download packages.
- A linux-config checkout containing `configs/dotfiles/emacs/doom-lite/`. The examples below assume it lives at `/opt/minh/linux-config`.
- External tools required by your enabled modules. Run `doom doctor` after installation to check for missing dependencies; `ripgrep` and `fd` are recommended for searching.

The core lives in this repository; the personal configuration lives in linux-config, not here. Only the vendored modules under `modules/` are available—do not assume every module listed in the upstream config template is supported.

## Install as your default Emacs

Use the installer in linux-config:

```bash
cd /opt/minh/linux-config

# Install both upstream Doom and Doom Lite, including their packages.
./lazarus.sh doom

# Select Doom Lite as the active installation.
./lazarus.sh doom-use lite
```

The installer places Doom Lite in `~/.config/doom-lite`. Selecting it points these symlinks at the matching core and configuration:

```text
~/.config/emacs -> ~/.config/doom-lite
~/.config/doom  -> /opt/minh/linux-config/configs/dotfiles/emacs/doom-lite
```

Switching stops the running `eterm` Emacs daemon, if present; it does not restart it. Save your work first. If the switch refuses because an existing configuration path is a real directory rather than a symlink, back it up and move it aside before retrying.

Check the installation and launch Emacs:

```bash
~/.config/emacs/bin/doom doctor
emacs
```

To switch back to upstream Doom:

```bash
cd /opt/minh/linux-config
./lazarus.sh doom-use doom
```

## Run a checkout without changing your default

Use explicit paths to try this repository or a worktree without switching `~/.config/emacs` or `~/.config/doom`:

```bash
git clone https://github.com/nqminhuit/doom-lite.git /opt/minh/doom-lite
cd /opt/minh/doom-lite

export EMACSDIR="$PWD/"
export DOOMDIR="/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite/"

bin/doom sync --env
bin/doom doctor
emacs --init-directory "$EMACSDIR"
```

Skip the clone if you already have a checkout, and adjust both paths as needed. Keep the exported variables set when running Doom commands or launching this checkout. This uses the existing linux-config configuration; edits to that configuration are shared with any other installation using it.

## Configure

Edit the files in your configuration directory (`~/.config/doom/` for the active installation, or `$DOOMDIR` when using explicit paths):

- `init.el`: enable or disable modules.
- `config.el`: settings and keybindings.
- `packages.el`: additional packages.

After changing module declarations or package declarations, run `doom sync` using the matching installation and restart Emacs:

```bash
~/.config/emacs/bin/doom sync
```

For an explicit checkout, use `bin/doom sync` with `EMACSDIR` and `DOOMDIR` set as above.

## Update

For the default Doom Lite installation:

```bash
git -C ~/.config/doom-lite pull
~/.config/emacs/bin/doom sync
```

Run this with Doom Lite selected, then restart Emacs. For a separate checkout, run `git pull` there and `bin/doom sync` with its explicit paths. Configuration updates are managed separately in linux-config. There is no `doom upgrade`.

## Tests

- `tests/run.sh`: smoke-test guards and unit tests.
- `tests/smoke.sh`: starts a daemon on the socket `doom-smoke` and checks startup, keybindings, and Java/Go modes.

Both need a linux-config checkout, located through `$DOOM_LITE_CONFIG` (default `/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite`); the config tests fail when it is missing.

See `doom-lite-plan.md` for the plan. Licensed under the terms in `LICENSE`.
