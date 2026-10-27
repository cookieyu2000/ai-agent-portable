#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "${TEMP}"' EXIT

bash -n "${ROOT}/install-nvidia.sh" "${ROOT}/install-codex.sh" "${ROOT}/install-claude.sh" "${ROOT}/install-all.sh"

mkdir -p "${TEMP}/bin"
printf '#!/bin/sh\nexit 0\n' > "${TEMP}/bin/codex"
printf '#!/bin/sh\nexit 0\n' > "${TEMP}/bin/claude"
chmod +x "${TEMP}/bin/codex" "${TEMP}/bin/claude"

nvidia_out="$(HOME="${TEMP}/home" AI_AGENT_SOURCE_ROOT="${TEMP}/sources" PATH="${TEMP}/bin:${PATH}" \
    "${ROOT}/install-nvidia.sh" --target both --dry-run)"
grep -Fq 'git clone https://github.com/NVIDIA/skills.git' <<< "${nvidia_out}"
grep -Fq 'compute-sanitizer-diagnose-cuda-bugs' <<< "${nvidia_out}"
grep -Fq '/.codex/skills/' <<< "${nvidia_out}"
grep -Fq '/.claude/skills/' <<< "${nvidia_out}"

for agent in codex claude; do
    output="$(HOME="${TEMP}/home" AI_AGENT_SOURCE_ROOT="${TEMP}/sources" PATH="${TEMP}/bin:${PATH}" \
        "${ROOT}/install-${agent}.sh" --with-nvidia --dry-run)"
    grep -Fq 'complete: NVIDIA' <<< "${output}"
done

if [[ -e "${TEMP}/home" || -e "${TEMP}/sources" ]]; then
    echo 'dry-run created external files' >&2
    exit 1
fi

skill_count="$(grep -c '^[a-z]' "${ROOT}/manifests/nvidia-skills.txt")"
[[ "${skill_count}" -eq 10 ]] || { echo "unexpected NVIDIA skill count: ${skill_count}" >&2; exit 1; }

printf 'NVIDIA integration dry-run tests passed\n'
