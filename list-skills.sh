#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_COMMAND="${PYTHON_COMMAND:-python3}"

command -v "${PYTHON_COMMAND}" >/dev/null 2>&1 || {
    printf 'error: required command not found: %s\n' "${PYTHON_COMMAND}" >&2
    exit 1
}

exec "${PYTHON_COMMAND}" "${SCRIPT_DIR}/scripts/skill_inventory.py" "$@"
