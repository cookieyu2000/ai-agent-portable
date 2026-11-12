#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_COMMAND="${PYTHON_COMMAND:-python3}"
command -v "${PYTHON_COMMAND}" >/dev/null || { printf 'error: Python 3.10+ is required\n' >&2; exit 1; }
exec "${PYTHON_COMMAND}" -B "${SCRIPT_DIR}/scripts/install_optional.py" "$@"
