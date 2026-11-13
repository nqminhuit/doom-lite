# FIX3

## Conductor brief
Conductor: `doom-lite-conductor`, set `doom-lite`; board `docs/handoff/doom-lite.md`. Report `STATUS FIX3: <state> | next | blocked | needs user` to the conductor.

Why now: the user recorded a test session of the fork (main checkout, `master` after PR #16). A frame review found these; the user wants all of them handled in one PR:
1. **`SPC SPC` (`m/find-file`, `config/modules/minh/utils/autoload.el` ~179) fails in projects under `~`**: `fd exited with 1: Search path '~/projects/gis/' is not a directory`. `project-root` returns `~`-abbreviated roots (since P5); expand before passing to `fd`. Grep `config/` and `modules/` for other `project-root` results handed to external programs unexpanded.
2. **jdtls dies on `~/projects/gis/src/main/java/org/nqm/Gis.java`** (git repo): `[eglot] -1: Server died … exited abnormally with code 1`, twice. Investigate first: reproduce through `bin/lite daemon`, read the `*EGLOT (gis/…) stderr*` and events buffers, and run the contact's jdtls command by hand. Check whether FIX2 (`jdtls-command-contact`, `+java--project`) or the fork's `user-emacs-directory` (`-data` under `lsp-cache`) is involved. If the cause is outside the fork and config (jdtls install, Java version, lombok jar), report it to the conductor before changing anything.
3. **Opening a `.sh` file errors when shellcheck isn't installed**: `(file-missing "Searching for program" … "shellcheck")` from `sh-shellcheck-flymake`. Don't add that backend (or remove it) when `shellcheck` isn't on `PATH`.
4. Check each against upstream Doom (read-only: `~/.config/emacs` source, never run or write it) and fix only if it is a fork regression: `SPC f C-g` prints `SPC f C-g is undefined` instead of quitting quietly (P8 keymaps?); which-key shows a raw `m/find-file` for `SPC :` and a literal `+<localleader>` for `m`; "Renamed tab to 'main'" printed at every startup (P6); an empty `[]` after the mode name in every file buffer's mode line.

Not bugs (leave): `SPC p a` refusing `/tmp` (excluded by design); `bin/lite client -c` without a running daemon; no live preview in `SPC /` and `SPC b b` (Doom default is `C-SPC`).

Work only in `/opt/minh/doom-lite-wt/FIX3` (branch off `origin/master`). Copy `.local` from `/opt/minh/doom-lite` (don't modify it) and run `yes y | bin/lite doom sync`. Never touch `~/.config/emacs`, `~/.config/doom` or the live daemon. Add unit or smoke tests for each fix. Force-push is denied. One PR to `master`; when ready, report it to the conductor, who reviews and merges it.
