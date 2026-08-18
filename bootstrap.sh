#!/usr/bin/env bash
set -euo pipefail

SOURCE="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$SOURCE")" && pwd)"
exec "$ROOT/install/bootstrap.sh" "$@"
