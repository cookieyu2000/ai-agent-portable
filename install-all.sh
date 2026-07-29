#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/install-codex.sh" "$@"
"${SCRIPT_DIR}/install-claude.sh" "$@"

