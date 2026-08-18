#!/usr/bin/env bash
set -euo pipefail

NVIM_VERSION="${NVIM_VERSION:-v0.12.4}"
LAZYGIT_VERSION="${LAZYGIT_VERSION:-0.64.1}"
UV_VERSION="${UV_VERSION:-0.12.5}"
DEV_TOOLS_PYTHON="${DEV_TOOLS_PYTHON:-3.12}"

export DEBIAN_FRONTEND=noninteractive

if ! command -v apt-get >/dev/null 2>&1; then
  echo "dev-env currently supports Debian/Ubuntu-compatible base images (apt-get required)." >&2
  exit 1
fi

apt-get update
apt-get install -y --no-install-recommends \
  bash \
  bash-completion \
  bat \
  build-essential \
  ca-certificates \
  curl \
  fd-find \
  file \
  fzf \
  git \
  htop \
  jq \
  less \
  openssh-client \
  rsync \
  sudo \
  tmux \
  tree \
  unzip \
  wget \
  xz-utils \
  zip
rm -rf /var/lib/apt/lists/*

ln -sf /usr/bin/fdfind /usr/local/bin/fd
if command -v batcat >/dev/null 2>&1; then
  ln -sf /usr/bin/batcat /usr/local/bin/bat
fi

# Neovim.
arch="$(dpkg --print-architecture)"
case "$arch" in
  amd64) nvim_arch="x86_64" ;;
  arm64) nvim_arch="arm64" ;;
  *) echo "Unsupported architecture for Neovim binary: $arch" >&2; exit 1 ;;
esac
curl -fsSL \
  "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${nvim_arch}.tar.gz" \
  -o /tmp/nvim.tar.gz
tar -xzf /tmp/nvim.tar.gz -C /opt
ln -sf "/opt/nvim-linux-${nvim_arch}/bin/nvim" /usr/local/bin/nvim
rm /tmp/nvim.tar.gz

# Yazi official apt repository.
curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg \
  -o /usr/share/keyrings/yazi-keyring.gpg
echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' \
  > /etc/apt/sources.list.d/yazi.list
apt-get update
apt-get install -y --no-install-recommends yazi
rm -rf /var/lib/apt/lists/*

# Lazygit.
case "$arch" in
  amd64) lg_arch="x86_64" ;;
  arm64) lg_arch="arm64" ;;
esac
curl -fsSL \
  "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${lg_arch}.tar.gz" \
  -o /tmp/lazygit.tar.gz
tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
install /tmp/lazygit /usr/local/bin/lazygit
rm -f /tmp/lazygit /tmp/lazygit.tar.gz

# uv is used both for generic IDE Python tooling and named research environments.
curl --proto '=https' --tlsv1.2 -LsSf \
  "https://releases.astral.sh/github/uv/releases/download/${UV_VERSION}/uv-installer.sh" \
  -o /tmp/uv-installer.sh
UV_INSTALL_DIR=/usr/local/bin sh /tmp/uv-installer.sh
rm /tmp/uv-installer.sh

# Generic Python tooling for Neovim. This is NOT a project environment.
# It exists so the standalone IDE image can run pyright/debugpy/ruff clients.
export UV_PYTHON_INSTALL_DIR=/opt/uv/python
uv python install "$DEV_TOOLS_PYTHON"
uv venv --python "$DEV_TOOLS_PYTHON" /opt/dev-tools
uv pip install --python /opt/dev-tools/bin/python debugpy pyright ruff
