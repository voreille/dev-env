#!/usr/bin/env bash
set -euo pipefail

SOURCE="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$SOURCE")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/config/versions.conf"

# nvim-treesitter/main requires tree-sitter-cli >= 0.26.1. Keep the pin in
# versions.conf when possible; this fallback keeps older checkouts bootstrappable.
TREE_SITTER_VERSION="${TREE_SITTER_VERSION:-0.26.12}"

PREFIX="${DEV_ENV_PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
OPT_DIR="$PREFIX/opt/dev-env"
SHARE_DIR="$PREFIX/share/dev-env"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dev-env"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TOOLS_VENV="$SHARE_DIR/python-tools"
FORCE=0
TOOLS=1
CONFIG=1

usage() {
	cat <<'USAGE'
Usage: ./install/bootstrap.sh [options]

Install the terminal IDE stack entirely in the current user's home directory.
No sudo/root access is used.

Options:
  --force        reinstall pinned binaries even when the expected version exists
  --tools-only   install binaries/tooling but do not link/supply dotfiles
  --config-only  link/supply dotfiles but do not install binaries
  -h, --help     show this help

Environment:
  DEV_ENV_PREFIX   user prefix, default: ~/.local
USAGE
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--force)
		FORCE=1
		shift
		;;
	--tools-only)
		CONFIG=0
		shift
		;;
	--config-only)
		TOOLS=0
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

mkdir -p "$BIN_DIR" "$OPT_DIR" "$SHARE_DIR" "$STATE_DIR" "$CONFIG_HOME"
export PATH="$BIN_DIR:$PATH"

TMP="$(mktemp -d -t dev-env-bootstrap.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

need() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "Missing required host command: $1" >&2
		exit 1
	}
}

if [[ "$TOOLS" == 1 ]]; then
	need curl
	need tar
	need python3
	need git
fi

arch="$(uname -m)"
case "$arch" in
x86_64 | amd64)
	NVIM_ARCH="x86_64"
	YAZI_ARCH="x86_64"
	LAZYGIT_ARCH="x86_64"
	RG_ARCH="x86_64"
	FD_ARCH="x86_64"
	FZF_ARCH="amd64"
	RUSTUP_TRIPLE="x86_64-unknown-linux-gnu"
	;;
aarch64 | arm64)
	NVIM_ARCH="arm64"
	YAZI_ARCH="aarch64"
	LAZYGIT_ARCH="arm64"
	RG_ARCH="aarch64"
	FD_ARCH="aarch64"
	FZF_ARCH="arm64"
	RUSTUP_TRIPLE="aarch64-unknown-linux-gnu"
	;;
*)
	echo "Unsupported architecture: $arch" >&2
	exit 1
	;;
esac

version_matches() {
	local cmd="$1" expected="$2" output
	[[ "$FORCE" == 0 ]] || return 1
	[[ -x "$BIN_DIR/$cmd" ]] || return 1
	output="$("$BIN_DIR/$cmd" --version 2>/dev/null)" || return 1
	[[ "$output" == *"$expected"* ]]
}

download() {
	local url="$1" out="$2"
	echo "  -> $url"
	curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 --max-time 600 \
		"$url" -o "$out"
}

install_nvim() {
	if version_matches nvim "$NVIM_VERSION"; then
		echo "Neovim $NVIM_VERSION already installed"
		return
	fi

	echo "Installing Neovim $NVIM_VERSION"
	local dst="$OPT_DIR/nvim-$NVIM_VERSION"
	rm -rf "$dst"
	download \
		"https://github.com/neovim/neovim-releases/releases/download/v${NVIM_VERSION}/nvim-linux-${NVIM_ARCH}.tar.gz" \
		"$TMP/nvim.tar.gz"
	tar -xzf "$TMP/nvim.tar.gz" -C "$TMP"
	mv "$TMP/nvim-linux-${NVIM_ARCH}" "$dst"
	ln -sfn "$dst/bin/nvim" "$BIN_DIR/nvim"
}

install_yazi() {
	if version_matches yazi "$YAZI_VERSION"; then
		echo "Yazi $YAZI_VERSION already installed"
		return
	fi

	echo "Installing Yazi $YAZI_VERSION"
	local triple="${YAZI_ARCH}-unknown-linux-musl"
	local dst="$OPT_DIR/yazi-$YAZI_VERSION"
	rm -rf "$dst" "$TMP/yazi"
	mkdir -p "$TMP/yazi" "$dst/bin"
	download "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-${triple}.zip" "$TMP/yazi.zip"
	python3 -m zipfile -e "$TMP/yazi.zip" "$TMP/yazi"
	local extracted="$TMP/yazi/yazi-${triple}"
	install -m 0755 "$extracted/yazi" "$dst/bin/yazi"
	install -m 0755 "$extracted/ya" "$dst/bin/ya"
	ln -sfn "$dst/bin/yazi" "$BIN_DIR/yazi"
	ln -sfn "$dst/bin/ya" "$BIN_DIR/ya"
}

install_lazygit() {
	if version_matches lazygit "$LAZYGIT_VERSION"; then
		echo "lazygit $LAZYGIT_VERSION already installed"
		return
	fi

	echo "Installing lazygit $LAZYGIT_VERSION"
	local dst="$OPT_DIR/lazygit-$LAZYGIT_VERSION"
	rm -rf "$dst"
	mkdir -p "$dst/bin"
	download \
		"https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_${LAZYGIT_ARCH}.tar.gz" \
		"$TMP/lazygit.tar.gz"
	tar -xzf "$TMP/lazygit.tar.gz" -C "$TMP" lazygit
	install -m 0755 "$TMP/lazygit" "$dst/bin/lazygit"
	ln -sfn "$dst/bin/lazygit" "$BIN_DIR/lazygit"
}

install_ripgrep() {
	if version_matches rg "$RIPGREP_VERSION"; then
		echo "ripgrep $RIPGREP_VERSION already installed"
		return
	fi

	echo "Installing ripgrep $RIPGREP_VERSION"
	local target="${RG_ARCH}-unknown-linux-musl"
	local dst="$OPT_DIR/ripgrep-$RIPGREP_VERSION"
	rm -rf "$dst"
	mkdir -p "$dst/bin"
	download \
		"https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${target}.tar.gz" \
		"$TMP/rg.tar.gz"
	tar -xzf "$TMP/rg.tar.gz" -C "$TMP"
	install -m 0755 "$TMP/ripgrep-${RIPGREP_VERSION}-${target}/rg" "$dst/bin/rg"
	ln -sfn "$dst/bin/rg" "$BIN_DIR/rg"
}

install_fd() {
	if version_matches fd "$FD_VERSION"; then
		echo "fd $FD_VERSION already installed"
		return
	fi

	echo "Installing fd $FD_VERSION"
	local target="${FD_ARCH}-unknown-linux-gnu"
	local dst="$OPT_DIR/fd-$FD_VERSION"
	rm -rf "$dst"
	mkdir -p "$dst/bin"
	download "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-${target}.tar.gz" "$TMP/fd.tar.gz"
	tar -xzf "$TMP/fd.tar.gz" -C "$TMP"
	install -m 0755 "$TMP/fd-v${FD_VERSION}-${target}/fd" "$dst/bin/fd"
	ln -sfn "$dst/bin/fd" "$BIN_DIR/fd"
}

install_fzf() {
	if version_matches fzf "$FZF_VERSION"; then
		echo "fzf $FZF_VERSION already installed"
		return
	fi

	echo "Installing fzf $FZF_VERSION"
	local dst="$OPT_DIR/fzf-$FZF_VERSION"
	rm -rf "$dst"
	mkdir -p "$dst/bin"
	download "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${FZF_ARCH}.tar.gz" "$TMP/fzf.tar.gz"
	tar -xzf "$TMP/fzf.tar.gz" -C "$TMP"
	install -m 0755 "$TMP/fzf" "$dst/bin/fzf"
	ln -sfn "$dst/bin/fzf" "$BIN_DIR/fzf"
}

install_uv() {
	if version_matches uv "$UV_VERSION"; then
		echo "uv $UV_VERSION already installed"
		return
	fi

	echo "Installing uv $UV_VERSION"
	download "https://releases.astral.sh/github/uv/releases/download/${UV_VERSION}/uv-installer.sh" "$TMP/uv-installer.sh"
	UV_INSTALL_DIR="$BIN_DIR" UV_NO_MODIFY_PATH=1 sh "$TMP/uv-installer.sh"
}

install_tree_sitter() {
	if version_matches tree-sitter "$TREE_SITTER_VERSION"; then
		echo "tree-sitter CLI $TREE_SITTER_VERSION already installed"
		return
	fi

	# Building on the host avoids prebuilt binaries that require a newer GLIBC.
	# Rust and Cargo live only in $TMP and are removed when bootstrap exits.
	need cc
	need c++

	echo "Installing tree-sitter CLI $TREE_SITTER_VERSION (compiled for this host)"
	local dst="$OPT_DIR/tree-sitter-$TREE_SITTER_VERSION"
	local cargo_home="$TMP/cargo-home"
	local rustup_home="$TMP/rustup-home"
	local rustup_init="$TMP/rustup-init"

	rm -rf "$dst" "$cargo_home" "$rustup_home"
	mkdir -p "$dst"
	download "https://static.rust-lang.org/rustup/dist/${RUSTUP_TRIPLE}/rustup-init" "$rustup_init"
	chmod 0755 "$rustup_init"

	CARGO_HOME="$cargo_home" RUSTUP_HOME="$rustup_home" \
		"$rustup_init" -y --profile minimal --default-toolchain stable --no-modify-path
	CARGO_HOME="$cargo_home" RUSTUP_HOME="$rustup_home" \
		"$cargo_home/bin/cargo" install --locked \
		--version "$TREE_SITTER_VERSION" \
		--root "$dst" \
		tree-sitter-cli

	ln -sfn "$dst/bin/tree-sitter" "$BIN_DIR/tree-sitter"
}

install_python_tools() {
	echo "Installing editor Python tooling using host python3"
	"$BIN_DIR/uv" venv --python "$(command -v python3)" --clear "$TOOLS_VENV"
	"$BIN_DIR/uv" pip install --python "$TOOLS_VENV/bin/python" debugpy pyright ruff

	local tool
	for tool in debugpy pyright pyright-langserver ruff; do
		[[ -e "$TOOLS_VENV/bin/$tool" ]] && ln -sfn "$TOOLS_VENV/bin/$tool" "$BIN_DIR/$tool"
	done
}

backup_and_link_dir() {
	local source="$1" target="$2" name="$3"
	mkdir -p "$(dirname "$target")"

	if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
		echo "$name config already linked"
		return
	fi

	if [[ -e "$target" || -L "$target" ]]; then
		local stamp backup
		stamp="$(date +%Y%m%d-%H%M%S)"
		backup="$STATE_DIR/backups/$stamp/$name"
		mkdir -p "$(dirname "$backup")"
		echo "Backing up existing $target -> $backup"
		mv "$target" "$backup"
	fi

	ln -s "$source" "$target"
	echo "Linked $target -> $source"
}

ensure_block() {
	local file="$1" start="$2" end="$3" body="$4"
	touch "$file"
	if grep -Fq "$start" "$file"; then
		return
	fi
	printf '\n%s\n%s\n%s\n' "$start" "$body" "$end" >>"$file"
}

configure_dotfiles() {
	backup_and_link_dir "$ROOT/dotfiles/nvim" "$CONFIG_HOME/nvim" nvim
	backup_and_link_dir "$ROOT/dotfiles/yazi" "$CONFIG_HOME/yazi" yazi
	mkdir -p "$CONFIG_HOME/dev-env"
	ln -sfn "$ROOT/dotfiles/bash/bashrc" "$CONFIG_HOME/dev-env/bashrc"
	ln -sfn "$ROOT/dotfiles/tmux/tmux.conf" "$CONFIG_HOME/dev-env/tmux.conf"

	ensure_block "$HOME/.bashrc" \
		'# >>> dev-env >>>' '# <<< dev-env <<<' \
		'[[ -f "$HOME/.config/dev-env/bashrc" ]] && source "$HOME/.config/dev-env/bashrc"'

	ensure_block "$HOME/.tmux.conf" \
		'# >>> dev-env >>>' '# <<< dev-env <<<' \
		'source-file ~/.config/dev-env/tmux.conf'
}

if [[ "$TOOLS" == 1 ]]; then
	install_nvim
	install_yazi
	install_lazygit
	install_ripgrep
	install_fd
	install_fzf
	install_uv
	install_tree_sitter
	install_python_tools
fi

if [[ "$CONFIG" == 1 ]]; then
	configure_dotfiles
fi

cat <<EOF_DONE

dev-env bootstrap complete.

Ensure this is on PATH (the supplied bash config does this for new shells):
  $BIN_DIR

Open a new shell, or run:
  source ~/.bashrc

Then verify with:
  $ROOT/scripts/doctor
EOF_DONE
