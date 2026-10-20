# CLAUDE.md

Personal, host-first terminal IDE (Neovim, Yazi, lazygit, tmux, rg/fd/fzf, uv) that
gets bootstrapped onto SSH research servers and local Linux machines. `README.md` is the
user-facing doc (workflow, keymaps); this file covers what matters when editing the repo.

## Hard constraints

- **No sudo / root, ever.** Everything installs under the user's home
  (`$DEV_ENV_PREFIX`, default `~/.local`). Don't add steps that need a package manager
  or system paths.
- **No Docker requirement.** dev-env runs directly on the host.
- **Must work on old, heterogeneous servers.** Prefer static/musl release binaries;
  build from source when a prebuilt binary needs a newer glibc (see `install_tree_sitter`,
  which builds with a throwaway Rust toolchain in `$TMP`). Support x86_64 and aarch64.
- **Don't take over Python environments.** Project envs are Conda (or a project `.venv`
  via uv). dev-env only owns a small editor-tooling venv (pyright, ruff, debugpy) at
  `~/.local/share/dev-env/python-tools`.
- **Be additive and reversible on the host.** Existing `~/.config/nvim|yazi` are backed up
  to `~/.local/state/dev-env/backups/` before symlinking; `~/.bashrc` and `~/.tmux.conf` only
  get a marked `# >>> dev-env >>>` source block (idempotent via `ensure_block`).

## Layout

- `bootstrap.sh` → thin wrapper exec'ing `install/bootstrap.sh` (the real installer).
  Flags: `--force`, `--tools-only`, `--config-only`, `--prune` (delete old version dirs; a new
  tool's dir name must be added to the `pinned` map in `prune_old_versions`).
- `config/versions.conf` — pinned tool versions, sourced by both bootstrap and doctor.
- `scripts/doctor` — checks versions, editor Python tools, host commands, config symlinks.
- `dotfiles/nvim/` — symlinked to `~/.config/nvim`. `init.lua` → `lua/config/{options,keymaps,lazy}.lua`.
  Nearly all plugin specs live in the single file `lua/config/lazy.lua`. `lazy-lock.json` is committed.
- `dotfiles/yazi/` — symlinked to `~/.config/yazi`.
- `dotfiles/bash/bashrc` — linked to `~/.config/dev-env/bashrc`, sourced from `~/.bashrc`.
  It sources `functions.sh` (tmux-work session layout, `conda-on`, `tconda`) via a
  **hardcoded `$HOME/dev-env` path** — the repo is expected to be cloned at `~/dev-env`.
- `dotfiles/tmux/tmux.conf` — linked to `~/.config/dev-env/tmux.conf`. tmux itself is
  *not* installed by bootstrap (assumed present on servers).
- `TODO.md` — deferred work (math as images, mermaid, texlab on old glibc).

Two installs deviate from the `ln -sfn` into `$BIN_DIR` pattern on purpose:

- **ImageMagick** comes from conda-forge via a throwaway micromamba in `$TMP` (with a fake
  `HOME`, so it never registers in `~/.conda/environments.txt`). The upstream AppImage needs
  glibc ≥ 2.35 and host libs.
- **TinyTeX** is *not* symlinked: `tlmgr` run through a symlink cannot find `mktexlsr`. Its
  `bin/<arch>` dir is put on PATH by `dotfiles/bash/bashrc`, by `lazy.lua` (for nvim), and by
  `dotfiles/nvim/scripts/tex-install-missing` (VimTeX hook that installs missing packages).
  Doctor checks it via the `tinytex` symlink, not `$BIN_DIR`.

Because configs are symlinks, edits to `dotfiles/` take effect immediately on a machine
that's already bootstrapped (restart nvim / re-source bash / `tmux source ~/.tmux.conf`).

## Common changes

- **Bump a tool:** edit `config/versions.conf`, then `./bootstrap.sh --force`; confirm with
  `./scripts/doctor`. Check that the release asset name/URL pattern in the matching
  `install_<tool>` function still matches upstream.
- **Add a tool:** add a `*_VERSION` pin, per-arch vars in the `uname -m` case, an
  `install_<tool>` function following the existing pattern (`version_matches` guard →
  install into `$OPT_DIR/<tool>-<version>` → `ln -sfn` into `$BIN_DIR`), call it in the
  `TOOLS` block, and add a `check_versioned` line in `scripts/doctor`.
- **Add a dotfile area:** link it in `configure_dotfiles` (use `backup_and_link_dir` for
  whole config dirs) and add a `check_link` in `scripts/doctor`.
- **Python interpreter for LSP/DAP** is resolved in `lua/config/lazy.lua` (`project_python`):
  project `.venv` → `VIRTUAL_ENV` → `CONDA_PREFIX` → dev-env python-tools. Keep README in
  sync if this order changes (the README's Debugging section currently lists the older order).

## Style

- Shell: `#!/usr/bin/env bash`, `set -euo pipefail` in installers, tabs for indentation in
  `install/` and `scripts/`, quote everything. Keep it shellcheck-clean.
- Lua: tabs, plugin specs grouped in `lazy.lua`.
- Commits: short `chore: ...` style messages.

## Verifying changes

There is no test suite. Useful checks:

```bash
bash -n install/bootstrap.sh scripts/doctor dotfiles/bash/*.sh
shellcheck install/bootstrap.sh scripts/doctor   # if available
nvim --headless "+Lazy! sync" +qa                 # plugin specs load
./scripts/doctor
```

Don't run `./bootstrap.sh` casually in a sandbox: it downloads binaries and modifies
`~/.bashrc`, `~/.tmux.conf` and `~/.config`.
