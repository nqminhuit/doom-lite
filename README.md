# doom-lite

A personal hard fork of Doom Emacs for Emacs 31. Only the modules I use are vendored under `modules/`, and the upstream tie is cut: updates come from this fork's git remote (`doom upgrade`).

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

For the default Doom Lite installation, with Doom Lite selected:

```bash
~/.config/emacs/bin/doom upgrade
```

This runs `git pull --ff-only` in `$EMACSDIR`, then `doom sync`. It aborts if the checkout has uncommitted changes to tracked files or can't fast-forward. Restart Emacs afterwards. For a separate checkout, run `bin/doom upgrade` with its explicit paths. Configuration updates are managed separately in linux-config.

## Bumping packages

```bash
bin/doom bump [PACKAGE...]
```

This looks up the newest upstream commit of each pinned package (the `:branch` of its recipe, if it has one), lists the repos that moved with a compare link each, asks for confirmation, then rewrites the `:pin` in the `packages.el` that sets it, commits the change, and runs `doom sync`. Pass package names to check only their repos; packages sharing a repo always move together.

- Answer `n` to only see the list.
- `-!` skips the confirmation.
- A trailing version comment on the pin line (for example `; 4.7.1`) is dropped, since it goes stale.
- It does not commit: restart Emacs, test, then commit. Pins edited in `$DOOMDIR` must be committed in that repo.
- Restart Emacs and test. Something broke? `doom rollback` (below) undoes it.

## Rolling back

```bash
bin/doom rollback
```

This undoes the last `doom bump` or `doom up` (only the most recent one is remembered, in `rollback.eld` under the Doom state dir), shows what it will undo, asks for confirmation (`-!` skips it), then runs `doom sync`.

- After a bump it reverts the bump commit(s) with `git revert`, and pushes the revert if the bump was pushed. It refuses if a commit is no longer in the history or its files have uncommitted changes, and if a revert conflicts it undoes any revert already made and keeps the record. A bump recorded by an older version, before bumps were committed, restores the original `packages.el` bytes instead.
- After `doom up` it resets the checkout to where it was before the pull and lists the commits and pin changes that go away. It refuses if the checkout moved on or has uncommitted changes. The next `doom up` pulls those commits again until they are reverted upstream.
- With nothing recorded it prints `Nothing to roll back`.

## Tests

- `tests/run.sh`: smoke-test guards and unit tests.
- `tests/smoke.sh`: starts a daemon on the socket `doom-smoke` and checks startup, keybindings, and Java/Go modes.

Both need a linux-config checkout, located through `$DOOM_LITE_CONFIG` (default `/opt/minh/linux-config/configs/dotfiles/emacs/doom-lite`); the config tests fail when it is missing.

See `doom-lite-plan.md` for the plan. Licensed under the terms in `LICENSE`.
