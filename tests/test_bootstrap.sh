#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

bash -n \
    "${BUNDLE_ROOT}/install-all.sh" \
    "${BUNDLE_ROOT}/install-codex.sh" \
    "${BUNDLE_ROOT}/install-claude.sh" \
    "${BUNDLE_ROOT}/scripts/bootstrap.sh" \
    "${BUNDLE_ROOT}/verify.sh"

codex_output="$(
    env -u CODEX_HOME -u CLAUDE_CONFIG_DIR \
    HOME="${TEST_ROOT}/home" AI_AGENT_SOURCE_ROOT="${TEST_ROOT}/sources" \
    "${BUNDLE_ROOT}/install-codex.sh" --dry-run
)"
grep -Fq '[dry-run]' <<<"${codex_output}"
grep -Fq 'github@openai-curated' <<<"${codex_output}"
grep -Fq 'i-have-adhd@i-have-adhd' <<<"${codex_output}"

claude_output="$(
    env -u CODEX_HOME -u CLAUDE_CONFIG_DIR \
    HOME="${TEST_ROOT}/home" AI_AGENT_SOURCE_ROOT="${TEST_ROOT}/sources" \
    "${BUNDLE_ROOT}/install-claude.sh" --dry-run
)"
grep -Fq '[dry-run]' <<<"${claude_output}"
grep -Fq 'agent-skills@addy-agent-skills' <<<"${claude_output}"
grep -Fq 'i-have-adhd@i-have-adhd' <<<"${claude_output}"

all_output="$(
    env -u CODEX_HOME -u CLAUDE_CONFIG_DIR \
    HOME="${TEST_ROOT}/home" AI_AGENT_SOURCE_ROOT="${TEST_ROOT}/sources" \
    "${BUNDLE_ROOT}/install-all.sh" --dry-run
)"
grep -Fq 'complete: codex bootstrap (dry-run)' <<<"${all_output}"
grep -Fq 'complete: claude bootstrap (dry-run)' <<<"${all_output}"

if find "${TEST_ROOT}" -mindepth 1 -print -quit | grep -q .; then
    printf 'dry-run created external files\n' >&2
    exit 1
fi

printf 'bootstrap tests passed\n'
