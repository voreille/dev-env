#!/usr/bin/env bash
set -euo pipefail

USERNAME="${1:-dev}"
USER_UID="${2:-1000}"
USER_GID="${3:-1000}"

if getent passwd "$USER_UID" >/dev/null 2>&1; then
  existing="$(getent passwd "$USER_UID" | cut -d: -f1)"
  if [[ "$existing" != "$USERNAME" ]]; then
    echo "UID $USER_UID is already owned by '$existing'; cannot create '$USERNAME'." >&2
    exit 1
  fi
fi

if ! getent group "$USER_GID" >/dev/null 2>&1; then
  groupadd --gid "$USER_GID" "$USERNAME"
fi
group_name="$(getent group "$USER_GID" | cut -d: -f1)"

if ! id "$USERNAME" >/dev/null 2>&1; then
  useradd --uid "$USER_UID" --gid "$group_name" -m -s /bin/bash "$USERNAME"
fi

echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
chmod 0440 "/etc/sudoers.d/$USERNAME"

mkdir -p \
  "/home/$USERNAME/.config/nvim" \
  "/home/$USERNAME/.config/yazi" \
  "/home/$USERNAME/.ssh" \
  "/home/$USERNAME/.local/share/nvim" \
  "/home/$USERNAME/.local/state/nvim" \
  "/home/$USERNAME/.cache/nvim" \
  "/home/$USERNAME/.cache/huggingface" \
  "/home/$USERNAME/.cache/torch" \
  "/home/$USERNAME/.cache/uv" \
  /workspaces

chown -R "$USER_UID:$USER_GID" "/home/$USERNAME" /workspaces /opt/dev-tools /opt/uv
