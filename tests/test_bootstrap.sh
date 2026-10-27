#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

mkdir -p "${TEST_ROOT}/bin"
printf '#!/usr/bin/env bash\nexit 0\n' >"${TEST_ROOT}/bin/codex"
printf '#!/usr/bin/env bash\nexit 0\n' >"${TEST_ROOT}/bin/claude"
chmod +x "${TEST_ROOT}/bin/codex" "${TEST_ROOT}/bin/claude"

bash -n \
    "${BUNDLE_ROOT}/install-all.sh" \
    "${BUNDLE_ROOT}/install-codex.sh" \
    "${BUNDLE_ROOT}/install-claude.sh" \
    "${BUNDLE_ROOT}/list-skills.sh" \
    "${BUNDLE_ROOT}/scripts/bootstrap.sh" \
    "${BUNDLE_ROOT}/verify.sh"

codex_output="$(
    env -u CODEX_HOME -u CLAUDE_CONFIG_DIR \
    HOME="${TEST_ROOT}/home" AI_AGENT_SOURCE_ROOT="${TEST_ROOT}/sources" \
    PATH="${TEST_ROOT}/bin:${PATH}" \
    "${BUNDLE_ROOT}/install-codex.sh" --dry-run
)"
grep -Fq '[dry-run]' <<<"${codex_output}"
grep -Fq 'github@openai-curated' <<<"${codex_output}"
grep -Fq 'i-have-adhd@i-have-adhd' <<<"${codex_output}"
grep -Fq '.codex/skills/backend-api-contracts' <<<"${codex_output}"
grep -Fq 'complete: NVIDIA 417-skill catalog for codex (dry-run)' <<<"${codex_output}"
awk '
    /complete: NVIDIA/ { nvidia = NR }
    /plugin add github@/ { if (!nvidia || NR <= nvidia) exit 1; found = 1 }
    END { if (!found) exit 1 }
' <<<"${codex_output}"

claude_output="$(
    env -u CODEX_HOME -u CLAUDE_CONFIG_DIR \
    HOME="${TEST_ROOT}/home" AI_AGENT_SOURCE_ROOT="${TEST_ROOT}/sources" \
    PATH="${TEST_ROOT}/bin:${PATH}" \
    "${BUNDLE_ROOT}/install-claude.sh" --dry-run
)"
grep -Fq '[dry-run]' <<<"${claude_output}"
grep -Fq 'agent-skills@portable-agent-skills' <<<"${claude_output}"
grep -Fq \
    "${TEST_ROOT}/sources/claude-marketplaces/portable-agent-skills" \
    <<<"${claude_output}"
grep -Fq 'i-have-adhd@i-have-adhd' <<<"${claude_output}"
grep -Fq '.claude/skills/karpathy-guidelines' <<<"${claude_output}"
grep -Fq '.claude/skills/backend-api-contracts' <<<"${claude_output}"
grep -Fq 'complete: NVIDIA 417-skill catalog for claude (dry-run)' <<<"${claude_output}"
if grep -Fq -- '--scope' <<<"${claude_output}"; then
    printf 'Claude dry-run uses unsupported --scope compatibility flag\n' >&2
    exit 1
fi

all_output="$(
    env -u CODEX_HOME -u CLAUDE_CONFIG_DIR \
    HOME="${TEST_ROOT}/home" AI_AGENT_SOURCE_ROOT="${TEST_ROOT}/sources" \
    PATH="${TEST_ROOT}/bin:${PATH}" \
    "${BUNDLE_ROOT}/install-all.sh" --dry-run
)"
grep -Fq 'complete: codex bootstrap (dry-run)' <<<"${all_output}"
grep -Fq 'complete: claude bootstrap (dry-run)' <<<"${all_output}"
[[ "$(grep -c 'complete: NVIDIA 417-skill catalog' <<<"${all_output}")" -eq 2 ]]

baseline_output="$(
    env -u CODEX_HOME -u CLAUDE_CONFIG_DIR \
    HOME="${TEST_ROOT}/home" AI_AGENT_SOURCE_ROOT="${TEST_ROOT}/sources" \
    PATH="${TEST_ROOT}/bin:${PATH}" \
    "${BUNDLE_ROOT}/install-codex.sh" --without-nvidia
)"
grep -Fq 'complete: codex bootstrap (dry-run)' <<<"${baseline_output}"
if grep -Fq 'NVIDIA' <<<"${baseline_output}"; then
    printf '%s\n' '--without-nvidia did not keep the original baseline' >&2
    exit 1
fi

if [[ -e "${TEST_ROOT}/home" || -e "${TEST_ROOT}/sources" ]]; then
    printf 'dry-run created external files\n' >&2
    exit 1
fi

printf 'bootstrap tests passed\n'
