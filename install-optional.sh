#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null || { printf 'error: Python 3.10+ is required\n' >&2; exit 1; }
exec python3 -B "${SCRIPT_DIR}/scripts/install_optional.py" "$@"
