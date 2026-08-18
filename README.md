# dev-env

A small, host-first terminal development setup for research servers and local Linux machines.

The current goal is deliberately narrow: **replace VS Code with a reproducible user-space terminal IDE without changing the way Python environments are managed yet**.

For now:

```text
host / SSH server
├── ~/.local/bin
│   ├── nvim
│   ├── yazi
│   ├── lazygit
│   ├── rg / fd / fzf
│   ├── uv
│   ├── pyright
│   ├── ruff
│   └── debugpy
├── conda environments        <- keep using these while learning the new tools
├── ~/workspaces
├── /mnt/nas*
└── Docker                    <- existing project containers only; research envs can move here later
```

There is **no Docker requirement for dev-env itself** and the bootstrap uses **no sudo**. Everything it installs lives under the current user's home directory.

## Layout

```text
dev-env/
├── bootstrap.sh
├── config/
│   └── versions.conf
├── dotfiles/
│   ├── nvim/
│   ├── yazi/
│   ├── tmux/
│   └── bash/
├── install/
│   └── bootstrap.sh
├── scripts/
│   └── doctor
└── README.md
```

## Bootstrap

Clone the repository, ideally as `~/dev-env`, then:

```bash
cd ~/dev-env
./bootstrap.sh
```

The script:

- installs pinned user-space binaries under `~/.local/opt/dev-env`;
- exposes commands through `~/.local/bin`;
- creates a small editor-tooling Python environment under `~/.local/share/dev-env/python-tools` using the host's existing `python3`;
- links Neovim and Yazi configs from this repo;
- adds a small sourced block to the existing `~/.bashrc` rather than replacing it;
- adds a sourced block to the existing `~/.tmux.conf` rather than replacing it;
- backs up an existing `~/.config/nvim` or `~/.config/yazi` before replacing it with a symlink.

It does **not** use or require root privileges.

For a dry first step you can install only the binaries:

```bash
./bootstrap.sh --tools-only
```

or only wire the configs:

```bash
./bootstrap.sh --config-only
```

Reinstall the pinned binaries after changing `config/versions.conf`:

```bash
./bootstrap.sh --force
```

## Check the setup

```bash
./scripts/doctor
```

`doctor` also reports optional/infrastructure commands such as `conda`, `tmux` and `docker`, but they are not requirements for the host IDE bootstrap.

## Current workflow with Conda

Nothing about Python environment management needs to change yet.

```bash
ssh server
cd ~/workspaces/plism
conda activate plism
nvim .
```

Launching Neovim **after activating the Conda environment** is useful because the supplied Python configuration sees `CONDA_PREFIX` and uses that interpreter for Python analysis/debugging when possible.

A second project can use another environment exactly as before:

```bash
cd ~/workspaces/other-project
conda activate other-env
nvim .
```

This lets you learn Neovim, Yazi, fuzzy search, lazygit and DAP without simultaneously changing dependency management.

## Files and search

Inside Neovim, `Space` is the leader and `,` is the local leader. Pause briefly after pressing `Space` to see available mappings through which-key.

```text
Ctrl-p        find files
Space p       document symbols/functions
Space f S     workspace symbols
Space f g     grep project text
Space f b     buffers
Space f r     recent files

gd            go to definition
gD            go to declaration
gr            references
K             hover documentation
Ctrl-o        jump back
Ctrl-i        jump forward

Space r n     rename symbol
Space c a     code action
Space l f     format

Space c n     browse/edit Neovim config
Space c b     edit dev-env bash config

Space d p     previous diagnostic
Space d n     next diagnostic
Space d e     diagnostic details

-             open Oil at the current file
```

Python files are formatted by Ruff on save. Pyright uses `standard` type checking. The Dracula colorscheme is enabled by default.

From the shell:

```bash
y              # Yazi wrapper; shell follows the directory selected on exit
lazygit
rg pattern
fd name
```

Yazi already uses Vim-like `h/j/k/l` navigation. Additional shortcuts:

```text
g w            ~/workspaces
g n            /mnt
Ctrl-h         toggle hidden files
```

## Python LSP / linting

The bootstrap keeps editor tooling separate from project environments:

```text
~/.local/share/dev-env/python-tools
├── pyright
├── ruff
└── debugpy
```

Pyright and Ruff are therefore always available to Neovim. When Neovim was launched from an activated Conda/virtual environment, the config points Python analysis at that interpreter.

Project dependencies still belong to the project's Conda environment / `pyproject.toml`, not to `dev-env`.

## Debugging

Default keys:

```text
F5       start / continue
F9       toggle breakpoint
F10      step over
F11      step into
F12      step out
Space du toggle debugger UI
Space dr debug REPL
Space dt debug nearest pytest method
```

For local Python debugging, the config prefers Python in this order:

1. active `VIRTUAL_ENV`;
2. active `CONDA_PREFIX`;
3. a local `.venv` in the current project;
4. the small dev-env Python tooling environment.

For your existing multi-container applications, keep using `debugpy` in the actual service container and attach from host Neovim. Remote targets can be supplied before starting Neovim:

```bash
export DAP_PYTHON_TARGETS='API=127.0.0.1:5678,Worker=127.0.0.1:5679'
nvim .
```

F5 will then include `Attach: API` and `Attach: Worker` configurations.

## tmux

The repo includes a tmux config, but the bootstrap intentionally does **not** try to build/install tmux itself: tmux does not provide the same simple official portable Linux release model as the other tools and often already exists on SSH servers.

If `tmux` exists, `~/.tmux.conf` sources the repo config after bootstrap. If it is absent, the rest of the setup still works.

## Why uv is already installed

`uv` is used only to maintain the small editor-tooling environment today. You can continue using Conda for research environments.

Later, when you want to migrate a research environment to Docker, the intended split is:

```text
Docker
    OS / CUDA / system libraries

uv
    Python + locked Python dependencies

host dev-env
    Neovim / Yazi / debugging UI
```

That can be added later without changing the host-side editor setup.

## Updating

Versions are pinned in:

```text
config/versions.conf
```

Edit the versions you want and run:

```bash
./bootstrap.sh --force
```

Neovim plugins are managed by `lazy.nvim`; use `:Lazy` inside Neovim when you want to inspect/update them.

## Uninstall / rollback

All installed binaries and editor tooling are contained under:

```text
~/.local/opt/dev-env
~/.local/share/dev-env
~/.local/bin/<symlinks created by bootstrap>
```

Existing Neovim/Yazi configs are backed up under:

```text
~/.local/state/dev-env/backups/
```

The bootstrap only adds clearly marked `dev-env` source blocks to `~/.bashrc` and `~/.tmux.conf`, so they can be removed manually if you stop using the setup.
