#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${REPOSITORY_ROOT}/tests/test_bootstrap.sh"
bash "${REPOSITORY_ROOT}/tests/test_nvidia_integration.sh"
python3 -m unittest discover \
    -s "${REPOSITORY_ROOT}/tests" \
    -p 'test_*.py' \
    -v
if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -File "${REPOSITORY_ROOT}/tests/test_nvidia_powershell.ps1"
elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${REPOSITORY_ROOT}/tests/test_nvidia_powershell.ps1"
fi
"${REPOSITORY_ROOT}/verify.sh"

printf 'all tests passed\n'
