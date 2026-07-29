#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
errors=0

check_file() {
    if [[ -f "${BUNDLE_ROOT}/$1" ]]; then
        printf 'ok: %s\n' "$1"
    else
        printf 'missing: %s\n' "$1" >&2
        errors=$((errors + 1))
    fi
}

check_file README.md
check_file manifests/sources.tsv
check_file manifests/agent-skills.txt
check_file manifests/codex-plugins.txt
check_file manifests/claude-plugins.txt
check_file skills/karpathy-guidelines/SKILL.md
check_file scripts/bootstrap.sh

while IFS=$'\t' read -r name url commit destination; do
    [[ "${name}" == \#* || -z "${name}" ]] && continue
    [[ "${url}" == https://github.com/*.git ]] || {
        printf 'invalid source URL: %s\n' "${url}" >&2
        errors=$((errors + 1))
    }
    [[ "${commit}" =~ ^[0-9a-f]{40}$ ]] || {
        printf 'invalid commit for %s: %s\n' "${name}" "${commit}" >&2
        errors=$((errors + 1))
    }
    [[ -n "${destination}" ]] || {
        printf 'missing destination for %s\n' "${name}" >&2
        errors=$((errors + 1))
    }
done <"${BUNDLE_ROOT}/manifests/sources.tsv"

skill_count="$(grep -c '^[a-z]' "${BUNDLE_ROOT}/manifests/agent-skills.txt")"
if [[ "${skill_count}" -eq 24 ]]; then
    printf 'ok: agent skill inventory (%s)\n' "${skill_count}"
else
    printf 'unexpected agent skill count: %s\n' "${skill_count}" >&2
    errors=$((errors + 1))
fi

if rg -n -i \
    '(api[_-]?key|access[_-]?token|refresh[_-]?token|password|private[_-]?key)[[:space:]]*[:=][[:space:]]*[^<${]' \
    "${BUNDLE_ROOT}" \
    --glob '!verify.sh' \
    --glob '!.git/**'; then
    printf 'possible secret assignment found\n' >&2
    errors=$((errors + 1))
else
    printf 'ok: no obvious secret assignments\n'
fi

if [[ "${errors}" -ne 0 ]]; then
    printf 'verification failed: %s issue(s)\n' "${errors}" >&2
    exit 1
fi

printf 'verification passed\n'

