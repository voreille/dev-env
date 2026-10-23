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
│   ├── magick                <- ImageMagick (conda-forge build) for images in nvim (snacks.image)
│   ├── pyright
│   ├── ruff
│   └── debugpy
├── ~/.local/opt/dev-env/tinytex   <- TinyTeX (pdflatex, latexmk, tlmgr); bin dir put on PATH by the bashrc
├── ~/.local/opt/dev-env/node      <- Node.js for the Copilot language server only; not on PATH
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
Space f w     grep word under cursor
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
├── debugpy
└── pylatexenc   (Markdown math, see below)
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

## Markdown math

`render-markdown.nvim` shows LaTeX math (`$...$`, `$$...$$`) as one-line Unicode in place of the
source, e.g. `\min \mathbb{E}\|W\phi(u)-u\|^2` → `min 𝔼‖Wϕ(u)−u‖²`. The source comes back on the
cursor line. Conversion is done by `dotfiles/nvim/scripts/tex2unicode` (pylatexenc + Unicode
super/subscripts); missing glyphs fall back to `_(...)` / `^(...)`. `:RenderMarkdown toggle` turns
rendering off.

## LaTeX

Bootstrap installs TinyTeX (a small TeX Live in `~/.local/opt/dev-env/tinytex`). Packages are
installed on demand: when a VimTeX build fails on a missing `.sty`/`.cls`/`.bst`/font,
`dotfiles/nvim/scripts/tex-install-missing` finds the TeX Live package that provides it, installs
it with `tlmgr`, and the build restarts (one round per missing dependency, a few seconds each).
Outside Neovim, run it on the log by hand: `tex-install-missing paper.log paper.blg`.
In Neovim, VimTeX builds with `latexmk` and texlab
(installed by Mason) provides completion and diagnostics:

```text
,ll   start/stop continuous build (rebuilds on save)
,lv   show the current line in the PDF
,le   errors and warnings
,lt   table of contents
,lc   clean auxiliary files
```

**Local machine:** install a viewer once (`sudo apt install zathura xdotool`). `,ll` opens the PDF in
zathura; Ctrl+click in the PDF jumps to the source line, `,lv` jumps the other way. Without
`xdotool` (Wayland), VimTeX uses `zathura_simple`, which may open a new window per jump.

**SSH server:** there is no viewer on the server. On the laptop (Pop!_OS: `sudo apt install
zathura rsync`), run

```bash
~/dev-env/scripts/pdf-follow server:path/to/main.pdf
```

It copies the PDF and its SyncTeX file with rsync every second into
`~/.cache/dev-env/pdf-follow/` and opens zathura, which reloads on each build. SyncTeX works both
ways over the same SSH connection: Ctrl+click in zathura moves the server's nvim and focuses the
terminal window running `ssh`/`kitten ssh` to that server (needs `xdotool`), and `,lv` in the
server's nvim moves zathura (within a second). Needs `rsync` on both machines and dev-env's nvim at
`~/.local/bin/nvim` on the server. Don't copy build files (`*.synctex.gz`, `*.fdb_latexmk`, …)
between machines: SyncTeX records absolute paths, so clicks would point at the other machine.

## tmux

The repo includes a tmux config, but the bootstrap intentionally does **not** try to build/install tmux itself: tmux does not provide the same simple official portable Linux release model as the other tools and often already exists on SSH servers.

If `tmux` exists, `~/.tmux.conf` sources the repo config after bootstrap. If it is absent, the rest of the setup still works.

To copy command output with full nvim motions, `Ctrl-b v` opens the pane's whole scrollback in nvim in a new window (`:q` returns). `Ctrl-b V` is plain tmux copy-mode (vi keys). To edit the current bash command line in nvim, use `Ctrl-x Ctrl-e`.

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

Each version installs into its own `~/.local/opt/dev-env/<tool>-<version>` and old ones are kept.
Delete the ones that are neither pinned nor still linked with:

```bash
./bootstrap.sh --prune
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
