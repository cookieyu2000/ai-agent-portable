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
check_file SKILLS.md
check_file .github/workflows/validate.yml
check_file list-skills.sh
check_file manifests/sources.tsv
check_file manifests/agent-skills.txt
check_file manifests/common-skills.txt
check_file manifests/codex-plugins.txt
check_file manifests/claude-plugins.txt
check_file claude-marketplaces/portable-agent-skills/.claude-plugin/marketplace.json
check_file skills/karpathy-guidelines/SKILL.md
check_file scripts/bootstrap.sh
check_file scripts/skill_inventory.py
check_file tests/test_skill_inventory.py

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

agent_skills_commit="$(
    awk -F '\t' '$1 == "agent-skills" { print $3 }' \
        "${BUNDLE_ROOT}/manifests/sources.tsv"
)"
agent_skills_version="${agent_skills_commit:0:12}"
if grep -F "\"version\": \"${agent_skills_version}\"" \
    "${BUNDLE_ROOT}/claude-marketplaces/portable-agent-skills/.claude-plugin/marketplace.json" \
    >/dev/null; then
    printf 'ok: portable Claude marketplace version (%s)\n' \
        "${agent_skills_version}"
else
    printf 'portable Claude marketplace version is not pinned to %s\n' \
        "${agent_skills_version}" >&2
    errors=$((errors + 1))
fi

if grep -F '"source": "./agent-skills"' \
    "${BUNDLE_ROOT}/claude-marketplaces/portable-agent-skills/.claude-plugin/marketplace.json" \
    >/dev/null; then
    printf 'ok: portable Claude marketplace uses local plugin source\n'
else
    printf 'portable Claude marketplace does not use its local checkout\n' >&2
    errors=$((errors + 1))
fi

common_skill_count="$(
    grep -c '^[a-z]' "${BUNDLE_ROOT}/manifests/common-skills.txt"
)"
if [[ "${common_skill_count}" -eq 26 ]]; then
    printf 'ok: common Codex/Claude baseline (%s)\n' "${common_skill_count}"
else
    printf 'unexpected common skill count: %s\n' "${common_skill_count}" >&2
    errors=$((errors + 1))
fi

while IFS= read -r skill_name; do
    [[ -n "${skill_name}" ]] || continue
    if ! grep -Fx "${skill_name}" \
        "${BUNDLE_ROOT}/manifests/common-skills.txt" >/dev/null; then
        printf 'common baseline is missing agent skill: %s\n' "${skill_name}" >&2
        errors=$((errors + 1))
    fi
done <"${BUNDLE_ROOT}/manifests/agent-skills.txt"

for skill_name in karpathy-guidelines i-have-adhd; do
    if ! grep -Fx "${skill_name}" \
        "${BUNDLE_ROOT}/manifests/common-skills.txt" >/dev/null; then
        printf 'common baseline is missing portable skill: %s\n' \
            "${skill_name}" >&2
        errors=$((errors + 1))
    fi
done

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
