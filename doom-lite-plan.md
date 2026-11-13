# Doom-lite fork: vendor modules, cut features, prefer built-ins

## Context
A personal hard fork of Doom Emacs (`~/.config/emacs`, running on Emacs 31.1). Goals: stop depending on upstream Doom, keep the Doom experience, make it lighter, remove features the user doesn't use, and use a built-in wherever one covers the job. Third-party packages stay only when they are clearly better than the built-in (vertico, consult, corfu, magit and similar).

User decisions:
- Vendor only the enabled modules into the repo and drop the `sources/doom+` submodule.
- Hard fork: no upstream merge compatibility.
- Swaps to make: smartparens → electric-pair, persp workspaces → tab-bar, general.el → built-in keymaps, dashboard → plain startup buffer, popup → `display-buffer-alist`, projectile → project.el.
- Swaps NOT to make: vertico/consult, corfu, magit, vc-gutter all stay.
- Project roots: VC roots (git/.jj) plus `.project` files.
- Package manager: replace straight with a small backend of the fork's own inside `doom sync` (clone at pin, add to load-path, generate autoloads, no package.el), done as the last phase. Chosen after S1 found package-vc needs as many workarounds as that backend.

Upstream is mid-migration. Projectile lives in `:doom compat +projectile`, at `modules/doom/compat/+projectile.el`. Its flags are hardcoded in `lisp/doom-modules.el:60-64`. Core helpers in `lisp/lib/projects.el` and `lisp/lib/buffers.el` still call projectile, while the user's `:minh` modules already use project.el, so today root detection is split between the two.

Everything lives in one repo, and each phase lists its **Fork** and **Config** changes separately:
- **fork** = `/opt/minh/doom-lite`, a checkout of `nqminhuit/doom-lite`, separate from the live `~/.config/emacs` (see Workspace).
- **config** = `config/` inside the fork: a copy of linux-config's `configs/dotfiles/emacs/doom-emacs/` taken from `master` at `3ced698a` (SETUP). Paths in a phase's **Config** section (`init.el`, `config.el`, `minh/...`) are relative to `config/`. The live config in `/opt/minh/linux-config` is never edited during the fork work; `config/` goes back to it at cutover.

This plan lives at the root of the fork repo (`doom-lite-plan.md`).

## Workflow
- Each phase is one branch and one draft PR in `nqminhuit/doom-lite` with base `master`, reviewed per CLAUDE.md. Phases are sequential: a phase branches off `master` after the previous phase is merged.
- A phase's fork and config edits are two separate stacea calls on the same branch and PR.
- Each worker works in its own git worktree of the fork, `/opt/minh/doom-lite-wt/<KEY>`; the main checkout `/opt/minh/doom-lite` stays on `master`. Each worktree has its own `.local` and needs its own first `doom sync`.
- A phase never edits the `doom+` submodule (until P1 removes it).
- The conductor reviews and merges each phase PR; the interactive list in Verification is the user's optional check after merge.
- Global invariants:
  - Keep the `map!`, `add-hook!`, `cmd!`, `define-key!`, `custom-set-faces!` and `after!` APIs.
  - Keep `doom-real-buffer-p`, `doom-font`, `doom-theme`, `doom-cache-dir` and `doom-escape-hook`.
  - Keep the C-i/C-m `key-translation-map` hack (`lisp/doom-emacs.el:807-825`). The user's `[C-m]` binding depends on it.
  - Keep the envvar file (`doom env`).
  - Keep `;;;###autoload` harvesting of the minh `autoload.el` files.
  - Deleting a module also removes the no-op `;;;###autodef` stubs Doom generates for it (`lisp/cli/loaddefs.el:67`). Every phase that deletes a module greps the remaining code for calls to that module's autodefs.

## Tests
The fork has no tests today. Tests are ERT (built in), live in `tests/`, and run locally with `tests/run.sh`; there is no CI for now, since it would need an Emacs 31 build.
- **Unit tests** (`tests/unit/*-tests.el`) run with `emacs --batch -Q`, loading only the file under test and its direct dependencies. They need no synced `.local`, except tests that need evil, which add its build dir to the `load-path` and are skipped with a message when it is missing.
- **Whole-config checks** are the scripted daemon checks in Verification. They live in `tests/smoke.sh`, need a synced `.local`, and are not part of the unit run.
- **Each phase adds unit tests for the code it writes.** The per-phase lists below are the minimum.
- **Old behavior first.** When a phase replaces the implementation behind an API that is kept (`map!`, `doom-project-root`, `set-popup-rule!`), its first commit adds tests that pass against the old implementation, and the rewrite must pass the same tests unchanged. A test that has to change records a deliberate behavior change, and the PR description says so.
- Tests use temp directories and temp keymaps, and never read `~/.config`, the user's config or the network.
- Not covered by tests: how things look (popup placement, startup buffer, which-key labels, terminals). Those stay in the user's optional interactive check.

## Workspace (isolation from the live Emacs)
The live install (`~/.config/emacs`, its `.local`, and `~/.config/doom` → `/opt/minh/linux-config/configs/dotfiles/emacs/doom-emacs`) is never edited or synced during the fork work, so the daily Emacs keeps working.

| | Live (untouched) | Fork workspace |
|---|---|---|
| Doom core | `~/.config/emacs` | `/opt/minh/doom-lite` (separate clone, own remotes and submodule state), one worktree per worker under `/opt/minh/doom-lite-wt/<KEY>` |
| Doom config | `/opt/minh/linux-config/.../doom-emacs` | `config/` in the same checkout or worktree |
| Packages/caches | `~/.config/emacs/.local` | `.local` in the same checkout or worktree |

Setup is done (see P0 and SETUP). To recreate the workspace on another machine, or a worker's worktree:
```sh
git clone --recurse-submodules git@github.com:nqminhuit/doom-lite.git /opt/minh/doom-lite
git -C /opt/minh/doom-lite worktree add -b <branch> /opt/minh/doom-lite-wt/<KEY> master
git -C /opt/minh/doom-lite-wt/<KEY> submodule update --init   # only while sources/doom+ exists (before P1)
```

Every command against the fork goes through the wrapper `bin/lite` (added in P1), which is the only supported way to run the fork until cutover:
```sh
bin/lite doom sync        # any doom subcommand
bin/lite emacs            # GUI test session
bin/lite daemon           # daemon on the socket `doom-lite`; never the default socket
bin/lite client -c        # emacsclient -s doom-lite ...
bin/lite stop             # kill the doom-lite daemon
```
What the wrapper does:
- Sets `EMACSDIR` to the checkout or worktree it lives in and `DOOMDIR` to `$DOOM_LITE_CONFIG`, defaulting to `config/` in that same checkout. Values already in the environment are overwritten, not trusted.
- Refuses to run, with a message and a non-zero exit, when after resolving symlinks `EMACSDIR` is `~/.config/emacs`, or `DOOMDIR` is `~/.config/doom`, lies under `/opt/minh/linux-config/`, or has no `init.el`.
- Passes `--init-directory "$EMACSDIR"` to every `emacs` call and `-s doom-lite` to every `emacsclient` call; `daemon` refuses to start if that socket is already live.
- `emacs`, `daemon` and `client` refuse to run, pointing at `bin/lite doom sync`, until the checkout's `.local` has a generated profile init (`.local/etc/@/init.*.el`); `doom` and `stop` always run.
- Is plain bash, passes shellcheck, and has no other logic.

Rules:
- Never call `bin/doom`, `emacs` or `emacsclient` directly for fork work; use `bin/lite`. The exceptions are SETUP and P1 before the wrapper exists, where both variables are exported by hand (`EMACSDIR` = the worktree, `DOOMDIR` = its `config/`, never a live dir) and every bare `emacs` call gets `--init-directory "$EMACSDIR"`. Never run `doom upgrade` at all (it pulls upstream; P1 deletes it).
- The first sync re-downloads ~80 packages into the workspace `.local` (79 build dirs, ~3.5 min at SETUP).
- The first sync does not install tree-sitter grammars. Without them, opening a Go or Java file asks "Missing tree-sitter grammars ... Install now?", which in a daemon blocks every client. After the first sync, copy them read-only from the live install: `mkdir -p .local/etc/tree-sitter && cp -p ~/.config/emacs/.local/etc/tree-sitter/*.so .local/etc/tree-sitter/`. `tests/smoke.sh` turns any prompt into an error so a check fails instead of hanging.
- Known leak: five places in `config/` hardcode `/opt/minh/linux-config` (`config.el:58` eshell aliases, `minh/java/config.el:40`, `minh/utils/autoload.el:3,79,84`), so the test session reads those files (read-only) from the live tree. Harmless as long as phases don't change them; don't rewrite the paths.

Baseline (SETUP, saved next to this plan as `doom-lite-baseline.md`): init time, package count, `doom doctor` output, and the outputs of the scripted smoke checks (see Verification), with the exact commands so P1's `tests/smoke.sh` can reproduce them.

## Cutover (after the last phase, user's call)
- Point `~/.config/emacs` at the fork (swap dirs or re-clone).
- If the live `.local` is reused rather than re-synced from scratch, delete the stale build dirs of packages that are now built in (P4: eglot, eldoc, flymake, jsonrpc, project, xref, seq, external-completion, transient, compat) from `.local/straight/build-31.1/`, then run `doom sync --rebuild`. straight still registers them as dependencies, so `doom gc` keeps them, and Doom puts registered build dirs on the `load-path` ahead of the built-ins.
- The live install needs the `markdown`, `markdown-inline`, `gomod` and `gowork` tree-sitter grammars (none are in the live `.local/etc/tree-sitter`): install them with `treesit-install-language-grammar` or `markdown-ts-mode-install-parsers` before first opening a `.md` file, or copy them from the fork's `.local/etc/tree-sitter`, which has all four. `go.mod`/`go.work` now map straight to `go-mod-ts-mode`/`go-work-ts-mode`, which prompt to install a missing grammar.
- Delete `bin/lite` and switch `tests/smoke.sh` to plain `bin/doom`, `emacs` and a test socket; the wrapper's refusals would block the fork once it is the live install.
- Copy `config/` back to linux-config's `configs/dotfiles/emacs/doom-emacs/` in one linux-config PR to `master`, so `~/.config/doom` picks it up. First diff it against linux-config `master`: any config change made live after `3ced698a` must be carried over, not overwritten.
- In the same linux-config PR, update `lazarus.sh` `_install_doom` (line 429 clones `doomemacs/doomemacs`; point it at the fork repo and check the `doom install`/`doom sync` calls still exist), its bats tests, and the Doom paragraph in `CLAUDE.md`.

## P0 — Fork repo (DONE)
- `/opt/minh/doom-lite` has `origin` = `git@github.com:nqminhuit/doom-lite.git` and `upstream` = `https://github.com/doomemacs/doomemacs` (reference only, never merged). The live `~/.config/emacs` remotes are unchanged.
- The live checkout was a shallow clone, which cannot be pushed, so `master` starts from one root commit: the tree of doomemacs `7ccac7f64` with the `sources/doom+` submodule at `f054be8f` (v26.11). There is no upstream history in the fork.
- There is no config worktree; the config lives in the fork's `config/` (see SETUP).

## SETUP — config, submodule, baseline (DONE)
- `sources/doom+` initialised at `f054be8f`.
- `config/` copied from linux-config `master` at `3ced698a` (18 files, no symlinks), from the commit rather than the working tree, so uncommitted live edits are not included.
- First `doom sync` and the baseline (`doom-lite-baseline.md`), run with `EMACSDIR`/`DOOMDIR` exported by hand to the SETUP worktree.

## S1 — package-vc spike (DONE)
Run on 2026-11-12 in scratch `user-emacs-directory`s. Findings, evidence and the user's decisions are in `docs/handoff/S1.md`; the parts P11 needs are folded into P11. In short: package-vc pins exactly, but vertico/corfu `extensions/` get no load-path or autoloads, archive deps come in unpinned, and evil/magit-section hit an activation recursion without `:ignored-files`. The user chose the fallback backend for P11, and a download-only ghostel module.

## P1 — Vendor enabled modules and cut the upstream tie
For each enabled module, copy `sources/doom+/modules/<cat>/<mod>/` to `modules/<cat>/<mod>/`. The enabled modules are:
- completion: corfu, vertico
- ui: dashboard, popup, vc-gutter, workspaces
- editor: evil
- emacs: electric, tramp, vc
- term: ghostel
- checkers: syntax
- tools: lookup, lsp, magit, tree-sitter
- lang: go, json, java, javascript, markdown, yaml
- config: default

Then:
- Remove the third entry from `doom-module-load-path` (`lisp/doom.el:185-188`).
- `git submodule deinit` and `git rm sources/doom+`, and clean up `.gitmodules`.
- Fix any path or doc references to `sources/doom+`, using `grep -rn "doom+" lisp bin`.
- `.gitignore` ignores `/modules/*/` except `modules/doom/`, so un-ignore the vendored categories and check `git status --ignored modules` shows none of them ignored.
- **Autodef stubs.** Vendored modules call autodefs defined in modules that are not vendored; today those are generated no-op stubs, after P1 they are void functions in lazily loaded code that `--debug-init` will not reach. Delete these calls (and their enclosing dead branch where there is one): `set-repl-handler!` (3), `set-eval-handler!` (1), `set-yas-minor-mode!` (2), `set-ligatures!` (1), `set-flyspell-predicate!` (1). `set-debug-var!` (3 calls) has no definition anywhere: find out what it is and delete the calls if it is dead. Re-run the check below until it prints nothing unexpected:
  ```sh
  for c in $(grep -rhoE "\(set-[a-z-]+!" modules | tr -d '(' | sort -u); do grep -rqE "^\(def(un|macro|alias)\*? .?$c( |$)" modules lisp || echo "undefined: $c"; done
  ```
- **Upstream tie.** Delete `bin/doom-upgrade` and the `upgrade` command wiring; a hard fork updates with `git pull`. Delete `docs/` except `docs/fleet/` and `docs/handoff/` (the fleet board and briefs), `static/`, `shell.nix`, `.github/` and `lisp/doom-elpaca.el` after a grep shows no loader references them. Replace the README with a short one for the fork.

- **Wrapper.** Add `bin/lite` as described in Workspace, as the first commit of the phase, and use it for everything after. Add a bats or plain-bash test for its refusals (live `EMACSDIR`, live `DOOMDIR`, missing `init.el`) that runs with a fake `HOME` and never starts Emacs.
- **Test scaffolding.** Add `tests/run.sh` (runs every `tests/unit/*-tests.el` in batch and fails on any failure), `tests/smoke.sh` (the scripted daemon checks from Verification) and one first unit test, for the undefined-autodef check above, so the runner has something to run.
- **Config ERT suite.** Port linux-config's `tests/elisp/minh-tests.el` to `tests/unit/minh-tests.el`, loading `minh/utils/autoload.el` and `minh/gis/autoload.el` from `config/modules/minh/` instead of the live tree, so `tests/run.sh` covers the config. At cutover it goes back to linux-config with `config/`.

Apart from the removed `doom upgrade`, this phase changes no behavior.

## P2 — popup → display-buffer-alist
**Fork:**
- Delete `modules/ui/popup`.
- Add a small `set-popup-rule!` / `set-popup-rules!` shim to core, so every module's existing calls keep working. Translation:
  - `:side` → `side`, `:size` → `window-height` or `window-width` depending on the side, `:slot` → `slot`
  - `:select t` → `(body-function . select-window)`; there is no native `select` entry
  - `:vslot`, `:ttl`, `:modeline`, `:autosave` → ignored
- Handle `:quit` with a `doom-escape-hook` function that closes side windows when ESC is pressed outside them.
- Delete the rest of the `+popup-*` references in vendored modules: `grep -rn "+popup" modules lisp`. This includes the popup toggle/raise bindings in `config/default`; rebind toggle to `window-toggle-side-windows` and drop raise.

**Tests:** for each of `:side`, `:size`, `:slot` and `:select`, `set-popup-rule!` adds the expected `display-buffer-alist` entry; ignored keywords add nothing and signal nothing; a rule for the same predicate replaces the earlier one; `set-popup-rules!` equals the same calls made one by one. In a batch frame, a matching buffer is displayed in a side window on the requested side.

**Config:**
- Drop `(popup +defaults)` from `init.el`.
- Replace the `+popup-buffer-mode` hook in `config.el:135` with a hook keyed on side-window buffers, or delete it.
- Keep the two `set-popup-rule!` calls, since the shim handles them.

## P3 — dashboard → plain startup buffer
**Fork:**
- Delete `modules/ui/dashboard`.
- Set `doom-fallback-buffer-name` to `*scratch*`.
- Remove dashboard references from other modules (`grep -rn "dashboard" modules lisp`).

**Config:**
- Drop `dashboard` from `:ui` in `init.el` only; the `:minh dashboard` module stays and is rewritten below.
- Rewrite `minh/dashboard/config.el` as a self-contained startup buffer with no `+dashboard-*` calls:
  - a local `m--insert-centered` helper
  - banner, then `emacs-init-time` plus the package count, then the calendar
  - shown via `initial-buffer-choice`, which also covers emacsclient frames
  - mode line hidden and `hl-line` off in that buffer

**Tests:** `m--insert-centered` centres with `:align-to center` using `string-width`; the startup buffer's name, mode, hidden mode line, hl-line off, contents (banner, package count line, current month), and rebuilding without duplication; `doom-fallback-buffer-name` is `*scratch*`.

## P4 — Built-in duplicates, Emacs 31 floor, dead code
- **Stop building ELPA copies of built-ins.** These are: eglot, eldoc, flymake, jsonrpc, project, xref, seq, external-completion, transient, use-package, bind-key, compat.
  - Checked on 31.1: the built-in and straight versions are identical for eglot, eldoc, flymake, jsonrpc, project, xref and seq. Built-in transient is 0.13.3 and magit requires 0.13.
  - **compat:** remove the ELPA copy and rely on the `compat.el` Emacs 31 ships (user decision). Risk: it is not confirmed that the built-in satisfies the `(compat "31")` that corfu, vertico, consult, embark, orderless, cape and magit require (ghostel needs 30.1). Do this as its own commit so it can be reverted alone.
    - How a failure shows up: `doom sync` fails resolving the `compat` dependency, or at runtime `Symbol's function definition is void: compat-...`, `Cannot open load file ... compat-31`, or a `compat` version error when one of those packages loads.
    - Fix if it happens: revert that commit, which restores `(package! compat :recipe (:host github :repo "emacs-compat/compat") :pin "90880f81419577e1d3f68424d2a3adf31e6d663e")` in `modules/doom/packages.el`, and record the error text here.
  - Remove their `package!` declarations, or mark them `:built-in t`. Sources: `modules/doom/packages.el`, `modules/doom/compat/packages.el`, tools/lsp, checkers/syntax, tools/magit. eldoc, seq and external-completion have no `package!` today (straight pulls them as dependencies), so they need an explicit `:built-in t` declaration.
  - Keep the `(package! which-key :built-in 'prefer)` behavior.
- **Set the minimum Emacs to 31** (`lisp/doom.el:81`), then delete the `doom-lib.el`/`doom-emacs.el` backport shims guarded by older-version checks.
- **Delete dead code under the user's flags:**
  - `config/default/+emacs-bindings.el` and its loader
  - every `modulep!` branch for a module that is not vendored. This is far more than ivy/helm: company, snippets, org, treemacs, neotree, spell, eval, debugger, multiple-cursors, format, fold and others (about 60 distinct targets). List them with `grep -rhoE "modulep! :[a-z]+ [a-z-]+" modules | sort | uniq -c` and resolve each to its constant value.
  - `tools/lsp/+lsp.el` and `autoload/lsp-mode.el`, keeping eglot only
  - `tools/lookup` `autoload/{docsets,online,xwidget}.el` and their callers, including the 8 `set-docsets!` calls
- **Config:**
  - `(package! evil-nerd-commentary :disable t)` is a typo for `evil-nerd-commenter`, which is installed and backs `gc`, the `c` text object and `s-/` (`editor/evil/config.el:433-436,563,642`, `config/default/config.el:162-163`). Delete the line here; P9 decides whether the package goes. Do not "fix" the typo, which would silently remove `gc`.
  - Drop disables that match nothing: evil-vimish-fold, doom-snippets, auto-yasnippet, drag-stuff, expand-region.
  - Remove the dead `+eglot/workspace-configuration` methods in `minh/java/config.el`. If the settings are needed, move them to `eglot-workspace-configuration`.

## P5 — projectile → project.el
**Fork:**
1. **New `lisp/doom-projects.el`**, required from `doom-emacs.el`. The `package! project` comment already names this file. Move into it from `+projectile.el`, without projectile:
   - `doom-fd-executable`, `doom-ripgrep-executable`, `doom-project-hook`, `def-project-mode!`
   - These are used by vertico, `lib/help.el` and lang/javascript, which would break without them.

   Move the `project` settings from `doom-emacs.el:1672-1681` here as well. Then set:
   - `project-vc-extra-root-markers` to `'(".jj" ".project")`
   - `project-list-exclude`: `doom-project-ignored-p`, `~/`, temp dirs
   - `project-compilation-buffer-name-function` to `project-prefixed-buffer-name`
   - `project-switch-commands` to `#'project-find-file`, so `SPC p p` jumps straight to find-file as Doom does instead of showing the dispatch menu
2. **Rewrite `lisp/lib/projects.el` on project.el:**
   - `doom-project-root` → `(when-let* ((p (project-current nil dir))) (project-root p))`
   - `doom-project-name` → `project-name`, keeping the dir-name / `"-"` fallback
   - `doom-project-find-file` → `project-find-file-in`
   - `doom/find-file-in-other-project` and `doom/browse-in-other-project` → `project-known-project-roots` minus the current project
   - `doom/add-directory-as-project` → write `.project` and call `project-remember-project`
   - `set-project-type!` → delete (it has no enabled callers)
3. **Other core files:**
   - `lib/buffers.el:74`: use `project-buffers`.
   - Delete the projectile cache code in `lib/files.el:404-407`, `lib/scratch.el:142` and `doom-docs.el:272`.
4. **Compat:** delete `compat/+projectile.el`, the `+projectile` flag (in `doom-modules.el` and `compat/{init,packages}.el`), and the `doom-projectile-fd-binary` alias.
5. **Modules:**
   - vertico: use `consult-dir-project-dirs` and drop the projectile marginalia entry.
   - magit: delete the cache-invalidation hook.
   - go: `+go/generate-all` → `(project-current t)`.
   - java and javascript: drop the `after! projectile` root and ignore blocks.
   - default `autoload/{search,files,default}.el`: port the known-projects and prefix-arg cases. `+default/discover-projects` → `project-remember-projects-under`.
   - workspaces: replaced in P6. Until then, the smallest change that keeps project switch working: a wrapper that reads `(project-root (project-current))` and calls `+workspaces-switch-project-function`.
6. **`SPC p` map** in `+evil-bindings.el`:

| key | new binding |
|---|---|
| p | project-switch-project |
| f | project-find-file |
| b | project-switch-to-buffer |
| k | project-kill-buffers |
| s | project-save-some-buffers |
| a | doom/add-directory-as-project |
| d | project-forget-project |
| ! | project-shell-command |
| & | project-async-shell-command |
| c | project-compile |
| D | +default/discover-projects |

`F`, `>`, `.`, `o`, `x` and `X` keep their Doom wrappers. `R`, `T`, `g`, `r`, `e` and `i` are dropped, with no new helpers.

**Tests** (in temp directories; the root cases are written first and must pass on the projectile version):
- `doom-project-root` returns the git root from a nested directory, the `.project` directory when one sits inside a git repo, and nil outside any project.
- `doom-project-name` returns the directory name, and `"-"` outside a project.
- `doom/add-directory-as-project` writes `.project` and the directory then appears in `project-known-project-roots`.
- A root matched by `project-list-exclude` is not remembered.
- Every key in the `SPC p` table resolves to the listed command.

**Config:** replace the `with-eval-after-load 'projectile` block (`config.el:227-235`) with `project-list-exclude` entries for `~/go/pkg/mod`. Remove the `"pC" nil` unbind.

## P6 — persp workspaces → tab-bar
**Fork:** replace `modules/ui/workspaces` with a small module built on `tab-bar-mode`. It keeps the command names the user binds:
- `+workspace/switch-to-0..8` → `tab-bar-select-tab`
- new, rename, kill, and display commands
- `SPC TAB` map
- project switch opens or reuses a tab named after the project and runs `+workspaces-switch-project-function`
- tab bar hidden: `tab-bar-show nil`. (`1` would show the bar as soon as there are two tabs.) The display command lists tabs in the echo area, as Doom does.

**Tests:** switching to a project creates a tab named after it, and switching again reuses that tab; `+workspace/switch-to-N` selects tab N and reports an out-of-range N without signalling; new, rename and kill change `tab-bar-tabs` as expected; killing the last tab leaves one tab.

**Buffer scoping changes.** persp isolated buffers per workspace; tab-bar does not. `SPC b b` becomes `project-switch-to-buffer`, falling back to `consult-buffer` outside a project.
- Update vertico's `+vertico/switch-workspace-buffer` and the persp references in vertico, evil, ghostel and default (`grep -rn "persp\|+workspace" modules lisp`).
- `lib/sessions.el` uses the desktop path only. Remove its persp branch.

**Config:**
- Remove the persp workaround comments in gis/keybindings where they become obsolete.
- Pulsar's `+workspace/switch-to-N` list stays valid.

## P7 — smartparens → electric-pair
**Fork:**
- Delete `compat/+smartparens.el` and the flag.
- Remove the `config/default +smartparens` flag handling and the `sp-*` and `smartparens` references in vendored modules (`grep -rn "sp-\|smartparens" modules lisp`).
- Enable `electric-pair-mode` in core defaults, in emacs/electric or doom-emacs.el.

**Config:**
- Drop `+smartparens` from `init.el`.
- In `abbrev/config.el`, replace `sp-point-in-string-or-comment` with `(nth 8 (syntax-ppss))`.
- Remove the eshell `smartparens-mode` hook in `config.el:63`.

## P8 — general.el → built-in keymaps
**Fork:** reimplement `map!`, `define-key!`, `undefine-key!` and the leader and localleader keys in `compat/+keybinds.el`, without general.
- **Before writing:** grep every keyword used in vendored modules and the config so the new `map!` supports exactly that set. Known so far: `:map`, `:leader`, `:localleader`, `:prefix`, `(:prefix ("x" . "desc"))`, `:desc`, `:after`, `:n`/`:i`/`:v`/`:m`/`:o`/`:g`, `:textobj`, `:keymaps`, nested groups, `:when`/`:unless`, `[remap ...]`, and nil unbinds. Also the `:general` keyword in `use-package!` forms (for example `editor/evil/config.el:436`).
- **Backend:**
  - `evil-define-key*` for state keys, `keymap-set`/`define-key` for the rest.
  - The leader lives in a `doom-leader-map` reached through a small always-on override minor mode. Bind the leader key on that mode's map per evil state with `evil-define-key*`, exactly as `doom-init-leader-keys-h` does today on `general-override-mode-map` (`+keybinds.el:124-135`): `doom-leader-key` in `doom-leader-key-states`, `doom-leader-alt-key` in `doom-leader-alt-key-states`. A plain SPC binding in an `emulation-mode-map-alists` map is not state-aware and would swallow SPC in insert state.
  - Check in general's source how `general-override-mode` wins over evil-collection and mode maps, and reproduce that precedence.
  - which-key labels via `which-key-add-keymap-based-replacements`.
- Replace the `general-auto-unbind-keys` calls in `lisp/lib/config.el:97,100` and `+keybinds.el:53`, and the `general-key-dispatch` reference in `lisp/doom-lib.el:869`.
- **Packages:** remove `package! general` and the `+keybinds` flag dependency on it.

**Tests** (written first against the general-based `map!`; the rewrite must pass them unchanged). Each binds into a temp keymap and asserts with `keymap-lookup` or `evil-lookup-key`:
- one test per supported keyword from the grep above, including nested groups and combined states such as `:nv`
- `:leader` and `:localleader` bindings land under `doom-leader-map` and the localleader prefix
- `(:prefix ("x" . "desc"))` and `:desc` register the which-key label
- `:when`/`:unless` bind or skip, `:after` defers until the feature loads, and a nil definition unbinds
- `define-key!` and `undefine-key!` with `:keymaps` taking one map and a list
- the leader key resolves to the leader map in normal, visual and motion states, and is unbound by the override map in insert state

**Config:** none expected. `map!` syntax is preserved. Verify `config.el:243` `define-key! :keymaps +default-minibuffer-maps`.

## P9 — Package audit (proposed; approving this plan approves this table)
After P1–P8 these third-party packages remain although a built-in covers the job. Change a row to "keep" to veto it.

| Package | Action | Built-in replacement |
|---|---|---|
| wgrep | drop | `grep-edit-mode` (in 31.1); update the vertico/embark export path and the evil wgrep wrapper in `editor/evil/autoload/evil.el` |
| go-mode | drop | `go-ts-mode`; go-tag and go-gen-test require go-mode, so they go too unless they work without it |
| json-mode, json-snatcher | drop | `json-ts-mode` |
| yaml-mode | keep | 31.1 `yaml-ts-mode` has no indentation; the module borrows `yaml-indent-line` (user, 2026-11-13) |
| markdown-mode, edit-indirect, markdown-toc | drop | `markdown-ts-mode` (in 31.1); reduce `lang/markdown` to the `auto-mode-alist` entry and grammar setup, and delete its markdown-mode bindings and config. Accepted loss: markdown-mode's editing commands and preview |
| dumb-jump | drop | xref with eglot; remove it from the lookup handler chain |
| gorepl-mode | drop | none needed; this also drops hydra, lv, s, f and dash, once markdown-toc is gone too |
| gcmh | drop | a fixed `gc-cons-threshold` restored after startup |
| auto-minor-mode | drop if no callers | none |
| evil-easymotion, avy | drop | avy is "disabled" in the config but still built as a dependency of evil-easymotion |
| git-timemachine | drop | `vc-region-history`, `vc-annotate` |
| git-link | drop | none; unused |
| git-modes | keep | no built-in gitignore/gitconfig modes |
| better-jumper | drop | vertico and lookup → `evil-set-jump`; **config:** pulsar → `evil-jump-backward`/`forward`; delete `compat/+better-jumper.el` |
| evil-nerd-commenter | drop | bind `gc` (normal and visual) to a small evil operator over `comment-or-uncomment-region`, and `s-/` and `[remap comment-line]` to the built-in `comment-line`. Accepted loss: the `c` comment text object |
| evil-args, evil-exchange, evil-indent-plus, evil-numbers (+ shift-number), evil-quick-diff, evil-textobj-anyblock, evil-traces, evil-visualstar, evil-escape, evil-surround | keep | kept for now; revisit after cutover |
| nerd-icons, nerd-icons-corfu | keep | no built-in |
| consult-dir, consult-eglot, embark, embark-consult, cape, orderless, diff-hl, evil-collection, ghostel, evil-ghostel | keep | per user decisions |

**Tests:** the `gc` operator comments and uncomments a line, a region and a motion (`gcap`) in a temp buffer with a comment syntax, and leaves point where evil-nerd-commenter did.

For each drop: remove the `package!`, its `use-package!` block and bindings, and grep for leftover references. Remove the now-redundant `:disable t` lines from the config `packages.el`.

## P10 — Core trims (proposed; approving this plan approves this list)
- **Delete:**
  - `lisp/doom-docs.el`, which needs org. Point `SPC h d` doc commands at the README files instead, or drop them.
  - `lisp/lib/sandbox.el` and its `config/default` binding
  - `lisp/lib/store.el` and `lisp/lib/plist.el`, after confirming no callers
  - `modules/doom/cli` (commit linter and test DSL)
  - `bin/org-capture`, `bin/doom.ps1`, `bin/doom.sh`
  - `profiles/`, if nothing but the default profile is used (confirm the profile loader does not need the directory)
- **compat module:** delete the deprecated aliases and macros that have no callers (`init.el`, after a grep).
- **Keep:** `doom.el`, `doom-lib.el`, `doom-modules.el`, `doom-emacs.el`, `lib/{files,text,ui,buffers,projects,config,help,debug,fonts,themes,scratch,sessions,process,system,git,strings}`, the CLI, and `doom env`.

## P11 — straight → clone-at-pin backend (detailed plan; approved by the user 2026-11-13)
Decided after S1 (`docs/handoff/S1.md`): no package.el, no package-vc, no recipe repos. `doom sync` keeps its name and flags it still needs, and gets a small backend of the fork's own: clone each package's repo at its pin, lay out a build dir per package, byte-compile in dependency order, generate autoloads, and let the generated profile init put the build dirs on the `load-path`. transient and the other P4 built-ins stay built in. ghostel's native module is download-only and lives outside the package tree.

### Inventory (2026-11-13, `master` at `0d16201`, synced tree copied from P10)
`doom-packages` holds 62 names. They split as:
- **16 built in** (`:built-in t`, or `'prefer` resolving to the Emacs copy): compat, project, eldoc, seq, external-completion, which-key, use-package, flymake, vc, vc-annotate, smerge-mode, eglot, jsonrpc, xref, transient, treesit. Not installed; unchanged.
- **9 disabled** in `config/packages.el`: groovy-mode, android-mode, marginalia, nodejs-repl, evil-lion, evil-embrace, exato, evil-snipe, flymake-popon. Not installed; unchanged.
- **straight** itself: deleted.
- **31 pinned and installed**, listed below.
- **5 installed without a pin**, from `config/packages.el`: pulsar, ecoin, gemit, s3-manager, podel. They get pins (Decision 1).

Installed today but **not declared** (straight pulled them from MELPA recipes): goto-chg (evil), shift-number (evil-numbers), llama, with-editor (magit, transient), magit-section (magit's repo). P11 declares each with the HEAD the synced tree has, so nothing changes. That makes 41 installed packages from 38 clones.

The table is the complete install set. "Files" is today's straight `:files` (from `.local/straight/build-31.1-cache.el`), minus `*-pkg.el`, `.texi` and docs entries; blank means the default set (below). Pins are full SHAs; where two packages share a repo they must share the pin.

| Package | Repo (github unless noted) | Pin | Files / notes |
|---|---|---|---|
| nerd-icons | rainstormstudio/nerd-icons.el | `17faac79…` | default + `data` dir |
| corfu | minad/corfu | `c68f993d…` | default + `extensions/corfu-*.el` |
| cape | minad/cape | `f0135aba…` | |
| nerd-icons-corfu | LuigiPiucco/nerd-icons-corfu | `e1197d6c…` | |
| vertico | minad/vertico | `cd2eb6da…` | default + `extensions/vertico-*.el` |
| orderless | oantolin/orderless | `51f677f4…` | |
| consult | minad/consult | `3a2441dd…` | |
| consult-dir | karthink/consult-dir | `1497b46d…` | |
| embark | oantolin/embark | `87e53827…` | `embark.el`, `embark-org.el` |
| embark-consult | oantolin/embark (shared) | `87e53827…` | `embark-consult.el` |
| evil | emacs-evil/evil | `6a3e1ddd…` | default, exclude `evil-test-helpers.el` |
| goto-chg (new) | emacs-evil/goto-chg | `72f556524b88e9d30dc7fc5b0dc32078c166fda7` | |
| evil-args | wcsmith/evil-args | `a8151556…` | |
| evil-escape | hlissner/evil-escape | `819f1ee1…` | |
| evil-exchange | Dewdrops/evil-exchange | `5f0a2d41…` | |
| evil-indent-plus | TheBB/evil-indent-plus | `f392696e…` | |
| evil-numbers | juliapath/evil-numbers | `616aff9e…` | not byte-compiled (today's `:build (:not compile)`) |
| shift-number (new) | codeberg: ideasman42/emacs-shift-number | `52f4d32080cca50da0f88b2141d597827c7341cf` | |
| evil-surround | emacs-evil/evil-surround | `e6548372…` | |
| evil-textobj-anyblock | willghatch/evil-textobj-anyblock | `29280cd7…` | pin is on branch `fix-inner-block`; fetched by SHA |
| evil-traces | mamapanda/evil-traces | `82e8a7b4…` | |
| evil-visualstar | bling/evil-visualstar | `06c053d8…` | |
| evil-quick-diff | rgrinberg/evil-quick-diff | `69c88372…` | |
| evil-collection | emacs-evil/evil-collection | `fa8da0eb…` | default + `modes` dir (compiled, 226 `.elc` today) |
| git-modes | magit/git-modes | `f291a4cc…` | |
| go-gen-test | s-kostyaev/go-gen-test | `af00a9ab…` | `go-gen-test.el` |
| yaml-mode | yoshiki/yaml-mode | `93dba98c…` | |
| ghostel | dakra/ghostel | `a63db707…` | default + `etc`, `src`, `vendor`, `build.zig`, `build.zig.zon`, `symbols.map` |
| evil-ghostel | dakra/ghostel (shared) | `a63db707…` | `extensions/evil-ghostel/*.el` |
| consult-eglot | mohkale/consult-eglot | `3e4d9a40…` | |
| cond-let | tarsius/cond-let | `09292a77…` | |
| llama (new) | tarsius/llama | `6850d0c91b629da14fdff2300c222289d1a0029a` | `llama.el` |
| with-editor (new) | magit/with-editor | `254c54189e26ed9223a55cba8bbd08b51c4b83c0` | |
| magit | magit/magit | `659f8995…` | `lisp/magit*.el`, `lisp/git-*.el`, exclude `lisp/magit-section.el` |
| magit-section (new) | magit/magit (shared) | `659f89955cf60fe3d4326d881c412df06c69680d` | `lisp/magit-section.el` |
| diff-hl | dgutov/diff-hl | `8dfb5c27…` | |
| pulsar | protesilaos/pulsar | `83d53271a0ec2728ef36b45704d47bafd170e814` | config |
| ecoin | nqminhuit/ecoin | `086ad6a2806466e8f8c09f8c217aec992092678b` | config |
| gemit | nqminhuit/gemit | `1291108abbb1945884941d3f928f718485dcb29f` | config |
| s3-manager | nqminhuit/s3-manager.el | `5abb3df5385138edc4d24d331700121b6e329527` | config |
| podel | nqminhuit/podel | `42e3db2078ab7dd3fadada2e3d84db89c7607bb8` | config |

Existing pins are abbreviated here; their full SHAs are the `:pin`s already in the modules. New pins are written in full (the HEADs of the synced tree).

Dependencies seen in the tree that are not packages here: `emacs`, `cl-lib`, `nadvice` (built into Emacs, so allowed without a declaration; see Rules). Checked 2026-11-13: for all 41 packages, `lm-package-requires` on `<package>.el` in the build dir gives exactly the dependency names straight recorded, so no recipe needs a dependency override.

### Design
**Layout** (new; `.local/straight/` goes away):
- `.local/packages/repos/<repo-name>/`: one shallow git checkout per repo, detached at the pin. `<repo-name>` is the repo's basename (`nerd-icons.el`, `emacs-shift-number`, ...), so shared repos clone once.
- `.local/packages/build-<emacs-version>/<package>/`: symlinks to the files the recipe selects; a directory entry (`data`, `modes`, `etc`) becomes a real directory holding symlinks to its files, as straight does, so every `.elc` is written into the build dir and never into the checkout. The build dir also holds the `.elc`s and `<package>-autoloads.el`. Byte-code stays per Emacs version as today, and the layout matches straight's, so library names, `locate-library` results and relative resource lookups (nerd-icons `data/`, ghostel `etc/`) are unchanged.
- `.local/packages/build-<emacs-version>/.state.el`: package → (pin, recipe hash, Emacs version), so a sync rebuilds only what changed.

**Recipe format.** `package!` stays (same keys: `:recipe`, `:pin`, `:disable`, `:built-in`, `:ignore`). Every installed package gets an explicit recipe in its `packages.el`; there are no recipe repos to fall back on. Recipe keys: `:host` (`github`, default, or `codeberg`), `:repo`, `:files`, `:compile` (nil to skip byte-compilation). `:branch` is accepted and ignored (the pin decides). Any other key, a missing `:repo`, or a `:pin` that is not 40 hex chars is an error at sync. `:files` uses a subset of straight's syntax: globs, `:defaults`, `(:exclude globs...)`; globs match relative to the repo root and land in the build dir under their basename. The default set is `("*.el" "lisp/*.el" (:exclude ".dir-locals.el" "test.el" "tests.el" "*-test.el" "*-tests.el" "*-pkg.el" "*-autoloads.el"))`, the `.el` part of MELPA's default.

**Rules** (every failure names the package and the `packages.el` that declared it). They run in two stages:
- **Before any network access:** every installed package has a full-SHA `:pin` and a valid recipe, and packages that share a repo have the same pin.
- **After all checkouts, before any build:** dependencies come from the `Package-Requires` header of the package's main file (`<package>.el` in its build file set, read with `lisp-mnt`). Each dependency must be `emacs`, a declared installed package, a package declared `:built-in`, or a library in Emacs's own `load-path` (`cl-lib`, `nadvice`); for a built-in, its version, from `package--builtins` (`finder-inf`, read only), must meet the required one (magit's `transient 0.13` against Emacs's 0.13.3; compat is 31.1.9999). The library check covers built-ins `finder-inf` does not list. Anything else (undeclared, or declared `:disable t`) is an error, never a fetch.
- Pinned build dirs go on the `load-path` ahead of Emacs's lisp dirs (the profile already adds the initial `load-path` first and package dirs in front of it). A `:built-in` package has no build dir, so it loads from the Emacs install.

**Fetch.** For a missing repo: `git init`, add the remote (`https://github.com/<repo>.git` or `https://codeberg.org/<repo>.git`), `git fetch --depth 1 --no-tags origin <pin>`, `git checkout --detach FETCH_HEAD`. If the shallow fetch by SHA fails, fall back to a full `git fetch origin` and checkout of the pin. Verified 2026-11-13 that the SHA fetch works for GitHub, Codeberg (shift-number) and a pin that only exists on a non-default branch (evil-textobj-anyblock). For an existing repo whose `HEAD` differs from the pin: same fetch, then checkout; the package and every package depending on it are rebuilt. After checkout, `git rev-parse HEAD` must equal the pin or the sync fails. git runs with the global and system git config ignored (as `doom--ensure-straight` does today), keeping the `DOOMGITCONFIG` escape hatch.

**Build** (in topological order of the dependency graph, dependencies first; a cycle is an error):
1. Recreate the build dir from the recipe's file set.
2. Byte-compile its `.el` files (recursively, so `modes/` is compiled) in a child `emacs --batch -Q` whose `load-path` is the package's build dir plus its transitive dependencies' build dirs, so a missing dependency shows up as a compile error instead of a silent skip. Compile warnings are logged, not fatal, as today; a file that fails to compile is reported and the sync exits non-zero at the end. Native compilation stays deferred (JIT at runtime), as today. With `--aot` gone, `doom-packages--compile-site-files`, `--wait-for-native-compile-jobs`, `--write-missing-eln-errors`, `--native-compile-done-h` and the eln/elc outdated checks go; `doom-packages--eln-output-path` stays for `doom gc`'s ELN purge.
3. `loaddefs-generate` over the build dir's top-level `.el` files into `<package>-autoloads.el` (with the existing `emacs-lisp-mode-hook` guard), which covers vertico's and corfu's extensions because they are flattened into the build dir.

**Profile.** `doom-initialize-packages` reads the declarations, validates them, and adds the build dirs to `load-path`. `doom-profile--generate-loaddefs-packages` walks the new dependency graph instead of `straight--build-cache` and inlines each package's autoloads file, dependencies first. The system-package branch that reads `package-alist` is dropped.

**ghostel module.** `modules/term/ghostel/config.el` sets `ghostel-module-auto-install` to `'download` and `ghostel-module-directory` to `(file-name-concat doom-data-dir "ghostel/")`, so re-cloning or rebuilding ghostel keeps the module, and the first terminal downloads it without a prompt. The zig compile path stays unsupported (`doctor.el` says so instead of suggesting `ghostel-module-compile`).

**`doom gc`.** Deletes repos and build dirs not used by the current package set, build dirs of other Emacs versions, and old ELN dirs (kept from today). Regrafting and the ELPA purge go: clones are already depth 1, and nothing installs into `.local/elpa`.

### What changes elsewhere (all consumers of straight)
- **Delete:** `lisp/doom-straight.el`; the bump tooling in `lisp/lib/packages.el` (everything but `doom/reload-packages`, which stays and is bound to `SPC h r p`); the `with-eval-after-load 'straight` block in `doom-emacs.el:218-220`; the `package!` for straight in `modules/doom/packages.el`; `doom-initialize-core-packages`, `doom--ensure-straight`, `doom--ensure-core-packages`, `doom-packages--cli-recipes-update`, `doom-packages--straight-with`, `doom-packages--with-recipes`, `doom-packages--barf-if-incomplete` (replaced by a check that every build dir exists), `doom-package-recipe-alist`, `doom-package-build-recipe`, `doom-package-depending-on`, and `unpin!`/`disable-packages!`/`:unpin`/`:freeze`/`:env`/`:type` (no callers outside comments; `:env` has no users and its profile generator `30-doom-package-envs` goes too).
- **Rewrite on the new backend:** `doom-packages-ensure`, `doom-packages-update` (now: bring every repo to its pin; there is nothing unpinned to update), `doom-package-recipe`, `doom-package-recipe-repo`, `doom-package-dependencies`, `doom-package-installed-p`, `doom-package-built-in-p`, `doom-package-backend` (`installed`/`builtin`/nil), `doom-package-pinned-alist`, `doom-package-homepage` (from the recipe's host and repo).
- `bin/doom-sync`: drop `-u` (nothing unpinned to update), `-U`, `--aot`, `-j` and `--gc` (gc always runs its full pass); keep `-r`, `-b`, `-B`, `-e`. The Emacs-version/system-hash rebuild prompt stays.
- `bin/doom-install`: drop the `--aot` straight hook. `bin/doom-gc`: rewritten as above. `bin/doom-doctor`: the stale-elc check points at the new build dir, and `(require 'straight)` goes.
- `lisp/doom-cli.el:1020-1043`: the straight error-log branch becomes a git-output branch: the backend keeps the last failing git or compile command's output and the error handler prints it the same way.
- `lisp/lib/help.el`: `doom/describe-package` lists packages from `doom-packages` and built-ins, and shows Source (Pinned / Built-in), Pin, repo dir, build dir and homepage from the new API; `doom/help-package-homepage` becomes a small command over `doom-package-homepage` (it aliases a straight function today). `lisp/lib/debug.el`: the `elpa` section of `doom-info` and its `unpin!` collection (`:340-342`) go.
- `lisp/doom-emacs.el:1535-1548`: the `package` block (MELPA/org archives) goes; Doom never uses package.el now. `package-enable-at-startup nil` (`doom.el:351`) stays.
- `lisp/doom-modules.el:37`, `lisp/lib/projects.el:156`, `lisp/doom.el:474`, `lisp/cli/loaddefs.el:126` and the commentary in `doom-packages.el`: drop straight wording.
- Tests and tools: `tests/unit/keybinds-tests.el:11`, `tests/unit/comment-tests.el:9` and `tests/smoke.sh:41` use `.local/straight/build-31.1/`; they move to a shared helper that returns `.local/packages/build-<emacs-version>/<package>`.
- Plan sections that go stale, edited by call D (not by this plan PR): Cutover's paragraph on stale built-in build dirs under `.local/straight/build-31.1/` (obsolete: the first sync of the new backend starts clean), Workspace's "first sync re-downloads ~80 packages (79 build dirs)" (now 41 packages from 38 clones), and the Verification **P11** bullet (replaced by the list below).

### Migration of an existing `.local`
Decision 2: the first sync on the new backend, seeing `.local/straight/`, prints that it is replacing the straight tree, deletes `.local/straight/` and `.local/elpa/`, and clones everything fresh (about 38 shallow clones; a few minutes once). No attempt to reuse straight's repos: the fresh path is the one verified, and nothing in the old tree is irreplaceable. Cases:
- **Worktrees** (copies of another worktree's `.local`): run `bin/lite doom sync`; the tree is rebuilt in place.
- **Main checkout** `/opt/minh/doom-lite`: the downloaded ghostel module sits inside `.local/straight/`, so it is deleted with it; the first ghostel terminal re-downloads it into `ghostel-module-directory` without a prompt.
- **Live install at cutover**: the same first sync replaces the live `.local/straight/`. Cutover's "delete stale build dirs then `doom sync --rebuild`" step is no longer needed (call D updates Cutover).

### Steps (stacea calls, one branch `p11-backend` off `master`, one PR)
Every call ends with `tests/run.sh`, `bin/lite doom sync`, `bin/lite doom doctor` and `tests/smoke.sh` green.

**A — fork, under straight: freeze today's layout and make every recipe explicit.**
1. First commit, before any other change: `tests/unit/packages-layout-tests.el` plus a fixture `tests/fixtures/packages-layout.eld` captured from the synced tree. For each installed package it records the sorted relative paths of the `.el` files in its build dir (recursively), the directories the recipe lists (nerd-icons `data`, evil-collection `modes`, ghostel `etc`, `src`, `vendor`), and the autoloaded function names its autoloads file defines; it also records `locate-library` for every `:built-in` package (must be under the Emacs install). The test compares the current synced tree with the fixture and skips with a message when `.local` is not synced. It must pass on straight.
2. Old-behavior unit tests (no sync needed) for the API kept: `package!` in a temp `packages.el` records `:pin`, `:recipe`, `:disable` and `:modules`; `:built-in t` marks `:ignore`; a later `package!` for the same name in the user dir overrides an earlier one; `doom-package-pinned-alist` maps repo names to pins and skips disabled and built-in packages.
3. Add `package!` declarations with pins for goto-chg (evil), shift-number (evil), llama, with-editor and magit-section (magit), each in the module that pulls it in, with a comment naming the dependent.
4. Give every installed module package an explicit `:recipe` with `:host`, `:repo` and `:files` taken from today's build cache (table above). Straight builds the same layout from these, which the layout test proves. Dropped from today's `:files`, outside what the fixture records: `*-pkg.el`, `.texi` and docs entries, `LICENSE`, `.dir-locals.el`, and magit's `githooks` directory (no Lisp uses it).

**B — config: pins for the five config packages** (Decision 1). Add `:pin` to pulsar, ecoin, gemit, s3-manager and podel in `config/packages.el`, and delete the `unpin!` example comments. The layout test still passes.

**C — fork: the backend swap.** Replace straight with the backend described in Design, in one call because the tree only works with all of it: `doom-packages.el` (rules, fetch, build, state, the rewritten API), the profile's package loaddefs generator, `doom gc`, `doom sync`/`install`/`doctor` flags, the CLI error branch, help/debug, the deletions listed above, and the test path helper. The layout test and old-behavior tests pass unchanged, except the fixture's paths now point under `.local/packages/`; any other change to the fixture is a behavior change and the PR says so. New unit tests, using temp `file://` git repos built in the test (no network):
- a package is checked out at its pin, and `git rev-parse HEAD` equals it; changing the pin moves the checkout and rebuilds the package and its dependents, but not unrelated packages
- an unpinned package, a short or non-hex pin, an unknown recipe key, and two packages on one repo with different pins each fail with an error naming the package before anything is fetched
- an undeclared dependency, a dependency on a disabled package, and a built-in below the required version each fail with an error naming the package after checkout and before anything is built
- dependencies are compiled before dependents; a dependency cycle is an error
- `:files` globs, `:defaults`, `:exclude` and directory entries produce the expected build dir; `:compile nil` produces no `.elc`
- a file from an extensions-style subdirectory gets autoloads (`vertico-directory-enter`-like) in `<package>-autoloads.el`
- gc removes a repo and build dir no longer declared, and keeps declared ones
- the build dir of a pinned package precedes an Emacs lisp dir in the generated `load-path` when both provide the same library

**D — fork: ghostel, migration, docs.** The ghostel settings and doctor text; the one-time `.local/straight` replacement; module READMEs and core docs that mention straight (`grep -rn straight modules lisp bin docs`); the stale plan sections listed above.

### Verification (phase-specific, on top of the every-phase list)
- **Fresh `.local`:** in the P11 worktree, move `.local` aside, run `bin/lite doom sync`, and check: 38 repos and 41 build dirs; for every installed package, `git -C <repo> rev-parse HEAD` equals its `:pin`; `git -C <repo> rev-list --count HEAD` is 1 (shallow) unless the SHA fetch fell back; the log shows no fetch without a SHA. Then copy the tree-sitter grammars back and run the full smoke.
- **Migration:** with a straight-era `.local` (the copy taken before call C), `bin/lite doom sync` removes `.local/straight/` and produces the same result as the fresh sync.
- **Layout:** the layout test passes against the fresh tree.
- Through the daemon: `(locate-library "transient")`, `"compat"`, `"eglot"`, `"project"`, `"seq"`, `"which-key"` and `"use-package"` point into the Emacs install; `(locate-library "magit")` and `"evil"` point under `.local/packages/build-31.1/`. `vertico-directory-enter` and `corfu-popupinfo-mode` are bound after `(require 'vertico-directory)` and `(require 'corfu-popupinfo)`. `(featurep 'straight)` is nil and `(fboundp 'straight-use-package)` is nil. `magit-version` is 4.7.1.
- ghostel: in the main checkout after the user's re-sync (interactive), the first terminal downloads the module into `.local/etc/ghostel/` (`doom-data-dir`) and `M-1..9` still work there.
- `grep -rn "straight" lisp bin modules tests config` returns only intentional hits (e.g. "straightforward", eglot's comment).
- Startup time and package count compared with the baseline: the package count is the number of build dirs (41).

### Decisions (user, 2026-11-13)
1. **Config packages are pinned** at the HEADs in the table (pulsar, ecoin, gemit, s3-manager, podel), like every other package. Bumping one means editing its `:pin` and running `bin/lite doom sync`.
2. **The old `.local/straight/` is deleted automatically** on the first sync of the new backend, with a message (see Migration).
3. **The listed surface is dropped:** `doom sync -u/-U/--aot/-j/--gc`, `unpin!`, `package!` `:env`/`:freeze`/`:type`, the bump commands, `doom gc` regrafting and ELPA purge, and the package.el archive setup in `doom-emacs.el`.

## Verification (every phase)
All commands run through `bin/lite` (see Workspace). stacea cannot press keys, so everything it runs is scripted; the interactive list is the user's optional check after merge.

Scripted (stacea runs these):
- `tests/run.sh` passes, including the unit tests the phase adds.
- `bin/lite doom sync` succeeds.
- `bin/lite doom doctor` shows nothing new against the baseline.
- `tests/smoke.sh` passes. It starts `bin/lite daemon`; then, through `bin/lite client --eval`, checks:
  - `*Messages*` and `*Warnings*` hold no errors or warnings
  - `(key-binding (kbd "SPC SPC"))`, `SPC p p`, `SPC b b`, `SPC /` and `SPC g g` each resolve to a command, checked in a file buffer in normal state
  - opening one Java and one Go file loads their modes without error
  - init time and package count, compared with the baseline
  - stop the daemon afterwards with `bin/lite stop`, also when a check fails
- Config phases: the config's ERT suite (`tests/unit/minh-tests.el`, ported in P1) passes as part of `tests/run.sh`.
- Grep for the symbols the phase removed (`grep -rn "<prefix>" lisp modules` and the config) returns only intentional hits.

Interactive (the user's optional check after merge; the conductor reviews and merges): `SPC SPC`, `SPC p p`, `SPC b b`, `SPC /`, magit status, eglot in one Java and one Go project, a ghostel terminal, and a `bin/lite client -c` frame.

Phase-specific checks:
- **P1:** the undefined-autodef loop prints nothing unexpected. `bin/doom upgrade` is gone.
- **P2:** `*Async Shell Command*` opens in the bottom side window and ESC closes it (`:quit 'current`, from inside the window); `*gis: *` opens in the left side window and stays open on ESC (`:quit nil`, user decision).
- **P4:** `ls .local/straight/build-31.1` in the fork no longer lists the built-in duplicates. `gc` still comments. compat: through the daemon, `(require 'vertico)`, `consult`, `corfu`, `embark`, `orderless`, `cape`, `magit` and `ghostel` all load, and `(locate-library "compat")` points into the Emacs install, not `.local`.
- **P5:**
  - `(featurep 'projectile)` is nil after use.
  - `grep -rn projectile lisp modules` returns only intentional hits.
  - The eglot root (`(project-root (eglot--project (eglot-current-server)))`) matches the git root in a nested Java/Go repo.
  - A `.project` dir is detected. `SPC p a` registers a directory.
- **P6:** Project switch creates a named tab, `M-1..9` and `SPC TAB 1..9` switch tabs, `SPC b b` is project-scoped, and no tab bar is drawn.
- **P8:** `SPC` leader works in magit, dired and ghostel buffers and types a space in insert state. which-key shows labels. `(featurep 'general)` is nil.
- **P9:** every dropped package is absent from the build dir, and `(featurep ...)` is nil for each after the smoke pass. A `.md` file opens in `markdown-ts-mode`. `gcc` and visual `gc` comment and uncomment.
- **P11:** On a fresh `.local`, `doom sync` clones every package at its pinned rev (`git rev-parse HEAD` equals the pin) and fetches nothing unpinned. `(locate-library "transient")` points into the Emacs install (built in since P4), and so do the other `:built-in t` packages. `vertico-directory-enter` and `corfu-popupinfo-mode` are bound. ghostel's module loads from `ghostel-module-directory`.

## Open decisions
None, and nothing is blocked.
