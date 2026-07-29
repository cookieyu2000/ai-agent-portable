#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${REPOSITORY_ROOT}/tests/test_bootstrap.sh"
python3 -m unittest discover \
    -s "${REPOSITORY_ROOT}/tests" \
    -p 'test_*.py' \
    -v
"${REPOSITORY_ROOT}/verify.sh"

printf 'all tests passed\n'
