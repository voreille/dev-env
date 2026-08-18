# dev-env

A terminal-first Docker development environment for AI/ML research.

The goal is to keep the **editor/debugging experience reusable** while letting each project own its Python/CUDA dependencies.

## Layout

```text
dev-env/
├── docker/
│   ├── Dockerfile.base
│   ├── Dockerfile.cuda
│   └── Dockerfile.cpu
├── dotfiles/
│   ├── nvim/
│   ├── yazi/
│   ├── tmux/
│   └── bash/
├── scripts/
│   └── dev
└── README.md
```

## What is included

- Neovim
  - native LSP + `nvim-lspconfig`
  - Pyright + Ruff
  - `blink.cmp` completion
  - `fzf-lua` file/content search
  - `oil.nvim` filesystem editing
  - `gitsigns.nvim`
  - `nvim-dap` + `nvim-dap-python` + `nvim-dap-ui`
- `debugpy`
- Yazi
- tmux
- lazygit
- ripgrep, fd, fzf, bat, jq, rsync, SSH client
- Python virtualenv at `/opt/venv`
- uv (available, but not required)

The base image does **not** install PyTorch or project libraries. Those belong in project-specific images.

## Host assumptions

This setup assumes Linux + Docker Engine.

For CUDA containers, the host also needs a working NVIDIA driver and NVIDIA Container Toolkit so Docker can expose GPUs.

The default locations are:

```text
~/workspaces     project repositories
/mnt/nas*        NAS mounts
~/dev-env        this repository
```

`~/workspaces` is mounted both:

1. at the **same absolute host path** inside the container; and
2. at `/workspaces` as a convenient alias.

Every existing `/mnt/nas*` directory is mounted at the same absolute path in the container.

NAS mounts are read/write by default. For read-only access:

```bash
DEV_NAS_MODE=ro dev shell cuda
```

## Install

Clone this repository to `~/dev-env`, then put `dev` on your PATH:

```bash
cd ~/dev-env
chmod +x scripts/dev

mkdir -p ~/.local/bin
ln -s ~/dev-env/scripts/dev ~/.local/bin/dev
```

Make sure `~/.local/bin` is on your host `PATH`.

## Build images

Build both CPU and CUDA variants:

```bash
dev build all
```

Or individually:

```bash
dev build cpu
dev build cuda
```

Default images:

```text
dev-env:cpu
dev-env:cuda12.3
```

The CUDA base currently uses:

```text
nvidia/cuda:12.3.2-cudnn9-runtime-ubuntu22.04
```

Override it without changing the repo:

```bash
DEV_CUDA_BASE_IMAGE=nvidia/cuda:<other-tag> dev build cuda
```

The image is built using your current host UID/GID so files written to bind-mounted workspaces and NAS storage remain owned by you.

## Basic workflow

From a project:

```bash
cd ~/workspaces/histoseg-plugin

dev shell cuda
```

This creates a persistent container named approximately:

```text
dev-histoseg-plugin-cuda
```

The shell starts in the corresponding project directory.

Open Neovim directly:

```bash
dev nvim cuda .
```

Open Yazi:

```bash
dev yazi cuda .
```

Run arbitrary commands:

```bash
dev exec cuda -- python -c 'import sys; print(sys.executable)'
dev exec cuda -- nvidia-smi
```

Lifecycle:

```bash
dev status cuda
dev stop cuda
dev rm cuda
```

Containers use `sleep infinity`, so leaving the shell or Neovim does not stop the development container.

## Multiple projects simultaneously

Each project gets a separate container because the container name is inferred from the current directory:

```bash
cd ~/workspaces/histoseg-plugin
dev start cuda

cd ~/workspaces/plism
dev start cuda
```

Result:

```text
dev-histoseg-plugin-cuda
dev-plism-cuda
```

This lets both projects run simultaneously with independent Python environments.

## Recommended project-specific image

The generic image supplies the IDE/tooling. Each project can derive a development image from it.

For HistoSeg, for example, keep something like this in the HistoSeg repository:

```dockerfile
# docker/Dockerfile.dev
FROM dev-env:cuda12.3

# /opt/venv is already writable by the dev user and is on PATH.
RUN pip install \
    torch==2.2.2 \
    torchvision==0.17.2 \
    --index-url https://download.pytorch.org/whl/cu121

# Add the rest of the reproducible project dependencies here.
# Source code itself is bind-mounted by the dev helper.
```

Build from the project repository:

```bash
cd ~/workspaces/histoseg-plugin
docker build -f docker/Dockerfile.dev -t histoseg-dev .
```

Then tell `dev` to use that image:

```bash
DEV_IMAGE=histoseg-dev dev shell cuda
```

or:

```bash
DEV_IMAGE=histoseg-dev dev nvim cuda .
```

For a persistent per-project choice, a tiny host-side wrapper or `.envrc` can export `DEV_IMAGE=histoseg-dev` later.

## Editable sibling repositories

Because the complete `~/workspaces` tree is mounted, sibling repositories remain available.

For example, inside the HistoSeg container:

```bash
pip install -e /workspaces/pathseg-benchmark
pip install -e /workspaces/histoseg-plugin
```

Those editable installs are written into that **container's `/opt/venv`**, not into another project's environment.

For full reproducibility, move such installs into the project's development Dockerfile once the workflow is settled.

## SSH

The helper forwards the host SSH agent when `SSH_AUTH_SOCK` is available. It also mounts these files read-only when present:

```text
~/.ssh/config
~/.ssh/known_hosts
~/.gitconfig
```

Private SSH keys are deliberately **not mounted into the container**.

Typical host workflow:

```bash
ssh-add ~/.ssh/id_ed25519
cd ~/workspaces/histoseg-plugin
dev shell cuda

git fetch
ssh some-other-server
```

## NAS

Every directory matching:

```text
/mnt/nas*
```

is detected when the container is first created and bind-mounted at the identical path.

Examples:

```text
/mnt/nas6  -> /mnt/nas6
/mnt/nas7  -> /mnt/nas7
```

If a NAS mount appears **after** the container was created, recreate the container so Docker receives the new bind mount:

```bash
dev rm cuda
dev start cuda
```

Read-only NAS mode:

```bash
DEV_NAS_MODE=ro dev shell cuda
```

## GPU selection

All GPUs are exposed by default for the CUDA variant.

Select one GPU at container creation:

```bash
DEV_GPUS='device=1' dev start cuda
```

Inside the container you can still use normal CUDA controls such as:

```bash
CUDA_VISIBLE_DEVICES=0 python train.py
```

## Ports / extra Docker options

The generic helper intentionally does not assume which services a project exposes.

For HistoSeg, for example:

```bash
DEV_IMAGE=histoseg-dev \
DEV_DOCKER_ARGS='-p 8090:8090 -p 5679:5679' \
dev start cuda
```

`DEV_DOCKER_ARGS` is intentionally interpreted as Docker CLI arguments, so only use values you control.

## Neovim essentials

The initial configuration is deliberately small.

### Navigation

```text
Space f f     find files
Space f g     live grep
Space f b     buffers
Space f r     recent files
Space f s     document symbols
-             Oil parent-directory browser
gd            go to definition
gr            references
K             hover
Space r n     rename
Space c a     code action
```

### Debugging

```text
F5            start / continue
F9            toggle breakpoint
F10           step over
F11           step into
F12           step out
Space d u     toggle debugger UI
Space d r     debugger REPL
Space d t     debug nearest pytest method
```

`nvim-dap-python` uses `debugpy` from `/opt/venv`. It can detect common project virtualenv directories such as `.venv` if you later choose to use one inside a project.

### Git

```bash
lazygit
```

or inspect inline hunks/signs directly in Neovim through `gitsigns.nvim`.

## Yazi

Run:

```bash
yazi
```

or use the shell helper:

```bash
y
```

`y` changes the shell's current directory to the directory you were in when you quit Yazi.

Useful custom bindings:

```text
g w           /workspaces
g n           /mnt
Ctrl-h        toggle hidden files
```

The normal Yazi Vim-style navigation remains unchanged.

## tmux

The image contains tmux, although for multi-project work it is often cleaner to run the main tmux session on the Docker host and put each project container in a separate tmux window.

The included config keeps the standard `Ctrl-b` prefix and adds:

```text
Ctrl-b |      horizontal split
Ctrl-b -      vertical split
Ctrl-b h/j/k/l  move between panes
Ctrl-b r      reload config
```

## Host tmux example

```text
tmux on server
├── histoseg
│   └── dev nvim cuda .
├── histoseg-shell
│   └── dev shell cuda
├── plism
│   └── dev nvim cuda .
└── gpu
    └── watch -n1 nvidia-smi
```

## Useful overrides

```bash
# Default to CPU on a machine without NVIDIA runtime.
export DEV_VARIANT=cpu

# Different workspace root.
export DEV_WORKSPACES_ROOT="$HOME/workspaces"

# Protect NAS data by default.
export DEV_NAS_MODE=ro

# Project image.
export DEV_IMAGE=histoseg-dev

# Explicit container name.
export DEV_CONTAINER_NAME=histoseg-devbox
```

## First smoke test

```bash
cd ~/dev-env
dev build cuda

cd ~/workspaces/histoseg-plugin
dev shell cuda
```

Inside:

```bash
python --version
python -m debugpy --version
pyright --version
ruff --version
nvim --version
yazi --version
lazygit --version
nvidia-smi
```

Then:

```bash
nvim .
```

On the first Neovim launch, `lazy.nvim` downloads the configured plugins into the persistent Neovim cache under `~/.cache/dev-env` on the host.

The five things worth validating before expanding the config are:

1. Pyright/Ruff diagnostics and `gd` work.
2. `Space f f` and `Space f g` feel fast.
3. `F9` + `F5` can debug your normal Python entry point.
4. Yazi is comfortable for filesystem-level navigation.
5. SSH/Git and `/mnt/nas*` access behave as expected.
