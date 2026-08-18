# dev-env

A terminal-first Docker development setup for AI/ML research, with one reusable IDE stack and two usage modes:

1. **Named research environments** — Docker captures the OS/CUDA/system stack, `uv` captures Python, and the IDE tooling is included in the same container.
2. **Standalone IDE service** — a generic `dev-env:ide` image can be added to an existing multi-service Docker Compose project (for example an API + GPU worker application) without changing the application images.

The design intentionally does **not** infer an environment from the current repository name. Named research environments are explicit and can be reused across multiple repositories.

## Layout

```text
dev-env/
├── config/
│   └── bases.conf
├── docker/
│   ├── Dockerfile.ide
│   └── Dockerfile.research
├── environments/
│   └── <name>/
│       ├── env.conf
│       ├── requirements.in
│       ├── requirements.lock.txt
│       └── system-packages.txt
├── examples/
│   └── compose.ide.override.yml
├── install/
│   ├── create-user.sh
│   └── install-ide.sh
├── dotfiles/
│   ├── nvim/
│   ├── yazi/
│   ├── tmux/
│   └── bash/
└── scripts/
    └── dev
```

## Mental model

### Research

```text
environments/histo/
  env.conf
  requirements.in
  requirements.lock.txt
       │
       │ dev build histo
       ▼
dev-env:histo
  arbitrary Ubuntu/CUDA base
  + IDE stack
  + uv-managed Python
  + locked shared research dependencies
       │
       │ dev shell histo
       ▼
dev-histo container
```

The image is reproducible. The running container is disposable.

A named environment can be used by several repositories:

```text
histo environment
├── ~/workspaces/plism
├── ~/workspaces/scorpion-analysis
└── ~/workspaces/other-histo-project
```

### Multi-service application

```text
Docker Compose
├── ide       <- dev-env:ide (generic)
├── api       <- project image
├── worker    <- project CUDA image
├── web
└── db
```

The IDE service shares the source mount and Compose network with the application services. `debugpy` remains in the actual service containers; Neovim DAP attaches to them.

## What is in the IDE stack

- Neovim
- Yazi
- lazygit
- tmux
- ripgrep, fd, fzf, bat, jq
- Git, SSH client, rsync
- `uv`
- generic IDE Python tooling in `/opt/dev-tools`
  - debugpy
  - Pyright
  - Ruff
- Neovim plugins for:
  - LSP and completion
  - fuzzy file/text search
  - Git hunks
  - Oil filesystem editing
  - DAP breakpoints and debug UI

The generic IDE tooling environment is **not** a project Python environment.

## Host assumptions

Defaults:

```text
~/dev-env       this repository
~/workspaces    repositories
/mnt/nas*       NAS mounts
```

Named research containers automatically mount:

- `~/workspaces` at the identical absolute host path inside the container;
- the same directory at `/workspaces` as a convenience alias;
- every existing `/mnt/nas*` directory at the same absolute path;
- persistent caches for Neovim, uv, Hugging Face and Torch;
- your Git config and SSH agent when available.

NAS mounts are read/write by default. Use:

```bash
DEV_NAS_MODE=ro dev shell histo
```

## Install the helper

For initial testing, call it directly:

```bash
~/dev-env/scripts/dev --help
```

If you want the shorter command later:

```bash
chmod +x ~/dev-env/scripts/dev
mkdir -p ~/.local/bin
ln -s ~/dev-env/scripts/dev ~/.local/bin/dev
```

The helper resolves symlinks, so this works correctly even when invoked from `~/.local/bin/dev`.

# 1. Named research environments

## Define base-image aliases

`config/bases.conf` contains convenient aliases:

```text
ubuntu22.04=ubuntu:22.04
ubuntu24.04=ubuntu:24.04
cuda12.3=nvidia/cuda:12.3.2-cudnn9-runtime-ubuntu22.04
```

List them with:

```bash
dev bases
```

You can edit this file to add CUDA/runtime combinations you use frequently. Full Docker image references also work directly.

## Create an environment

CPU example:

```bash
dev create generic-ml \
    --base ubuntu24.04 \
    --python 3.12 \
    --gpus none
```

CUDA example:

```bash
dev create histo \
    --base cuda12.3 \
    --python 3.10 \
    --gpus all
```

This creates:

```text
environments/histo/
├── env.conf
├── requirements.in
└── system-packages.txt
```

`env.conf` describes the machine-level choices:

```bash
BASE_IMAGE="cuda12.3"
PYTHON_VERSION="3.10"
GPUS="all"
```

`system-packages.txt` is for environment-wide apt dependencies such as OpenSlide libraries.

`requirements.in` is the human-curated **shared research environment**, not an application package definition.

Example:

```text
numpy<2
pandas>=2
scipy
scikit-learn
lightning
```

Keep repository-specific dependencies in the repository's own `pyproject.toml`.

## Add dependencies

The Conda-like convenience command is:

```bash
dev add histo h5py 'numpy<2' scikit-image
```

This:

1. records the requested packages in `requirements.in`;
2. regenerates `requirements.lock.txt`;
3. if `dev-histo` is already running, installs the packages there immediately as well.

The Docker image remains unchanged until you rebuild it. The specification is therefore never dependent on mutable container state.

For a special package index, edit `requirements.in` directly and run `dev lock histo`. Pip-style index directives can live in the requirements file.

## Lock

```bash
dev lock histo
```

To deliberately update pinned transitive versions:

```bash
dev lock histo --upgrade
```

`requirements.lock.txt` should be committed to Git. It is the reproducible resolved Python environment.

## Build

```bash
dev build histo
```

This builds:

```text
dev-env:histo
```

The research Dockerfile:

1. starts from the selected base image;
2. installs the common IDE stack;
3. installs optional apt dependencies;
4. lets `uv` install the requested Python version;
5. creates `/opt/venv`;
6. exactly syncs the locked Python dependencies into `/opt/venv`.

If you rebuilt the image while an old working container exists, that existing container still points to the old image. To rebuild and discard the old working container in one command:

```bash
dev rebuild histo
```

## Work in it

From any repository using that environment:

```bash
cd ~/workspaces/plism
dev shell histo
```

or directly:

```bash
dev nvim histo .
dev yazi histo .
```

The container is named by the **environment**, not by the repository:

```text
dev-histo
```

So the same environment/container can be reused from another repository:

```bash
cd ~/workspaces/scorpion-analysis
dev nvim histo .
```

## Install a repository editable

The shared environment and the repository remain separate concepts.

If the repository has its own `pyproject.toml`:

```bash
cd ~/workspaces/plism
dev install histo .
```

is equivalent to installing the repository editable into `/opt/venv`:

```bash
uv pip install --python /opt/venv/bin/python -e .
```

If you destroy the working container, the shared environment comes back from `requirements.lock.txt`, while project dependencies come back from the repository's own `pyproject.toml` by rerunning `dev install`.

## Lifecycle

```bash
dev list

dev status histo
dev stop histo
dev rm histo
```

Removing `dev-histo` does not remove `dev-env:histo` and does not remove the environment specification.

Even deleting both the container and image is safe:

```bash
dev build histo
```

recreates the image from the committed files.

# 2. Generic IDE image for Compose applications

Build once:

```bash
dev ide build
```

This creates:

```text
dev-env:ide
```

It is deliberately independent of CUDA, PyTorch, OpenSlide, or any application.

You can test it standalone:

```bash
dev ide shell
dev ide nvim ~/workspaces/some-repo
```

For a multi-service application, add it through a Compose override instead. See:

```text
examples/compose.ide.override.yml
```

Minimal idea:

```yaml
services:
  ide:
    image: dev-env:ide
    working_dir: /workspace/my-project
    volumes:
      - .:/workspace/my-project
    environment:
      DAP_PYTHON_TARGETS: "API=api:5678,Worker=worker:5679"
    stdin_open: true
    tty: true
    command: sleep infinity
```

Then:

```bash
docker compose -f compose.yml -f compose.ide.override.yml up -d
docker compose exec ide nvim .
```

If the API and worker run debugpy on their internal Compose ports, F5 in Neovim will include attach targets from `DAP_PYTHON_TARGETS`.

Example application service command:

```bash
python -m debugpy --listen 0.0.0.0:5678 --wait-for-client -m my_api
```

Because the IDE service and application services share the Compose network, those debug ports do not need to be published to the host for IDE-to-service debugging.

For painless breakpoints, mount source code at the same container path in the IDE and the debugged service whenever possible.

## Generic IDE LSP caveat

The standalone IDE image intentionally does not contain your application's Python dependencies. Pyright still provides source-level navigation/type analysis, but missing third-party import diagnostics are suppressed in standalone IDE mode to avoid noise.

For named research images, `/opt/venv` exists and normal missing-import diagnostics remain enabled.

If a multi-service project later needs dependency-aware LSP from the application environment, that can be added separately without changing the editor/container architecture.

# Why `uv` rather than Conda here?

Docker already owns the layer Conda often helps manage in ML workflows:

```text
Docker
  OS / glibc / CUDA / cuDNN / system packages

uv
  Python version / virtual environment / Python packages / exact lock
```

For reusable research environments, this repo intentionally uses the `uv pip` interface with `requirements.in` + `requirements.lock.txt` rather than another `pyproject.toml`, because actual repositories already own their project metadata in `pyproject.toml`.

# Useful overrides

```bash
DEV_WORKSPACES_ROOT=/other/workspaces dev shell histo
DEV_NAS_MODE=ro dev shell histo
DEV_GPUS='device=1' dev shell histo
DEV_DOCKER_ARGS='--shm-size=16g' dev shell histo
DEV_IDE_BASE_IMAGE=ubuntu:22.04 dev ide build
```

# Current pinned tooling

The Dockerfiles currently pin:

```text
Neovim   0.12.4
lazygit  0.64.1
uv        0.12.5
```

Update the corresponding build arguments when you intentionally upgrade the workstation stack.
