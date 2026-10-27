#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "${TEMP}"' EXIT

fail() { printf '%s\n' "$*" >&2; exit 1; }
expect_failure() {
    local expected="$1" output
    shift
    if output="$("$@" 2>&1)"; then
        fail "command unexpectedly succeeded: $*"
    fi
    grep -Fq -- "${expected}" <<<"${output}" || fail "expected ${expected}; got ${output}"
}

bash -n "${ROOT}/install-nvidia.sh" "${ROOT}/scripts/bootstrap.sh"
mapfile -t skills < <(grep -E '^[a-z0-9][a-z0-9-]*$' "${ROOT}/manifests/nvidia-skills.txt")
[[ "${#skills[@]}" -eq 417 ]] || fail "unexpected NVIDIA skill count: ${#skills[@]}"
first="${skills[0]}"
last="${skills[${#skills[@]}-1]}"
commit="$(awk -F '\t' '$1 == "nvidia-skills" { print $3 }' "${ROOT}/manifests/sources.tsv")"

mkdir -p "${TEMP}/bin" "${TEMP}/bundle/scripts"
cp "${ROOT}/install-nvidia.sh" "${TEMP}/bundle/"
cp "${ROOT}/scripts/bootstrap.sh" "${TEMP}/bundle/scripts/"
cp -R "${ROOT}/manifests" "${ROOT}/skills" "${ROOT}/claude-marketplaces" "${TEMP}/bundle/"
cat >"${TEMP}/bin/codex" <<'EOF'
#!/usr/bin/env bash
if [[ "${FAKE_ADHD_PLUGIN:-false}" == true && "$*" == 'plugin list --json' ]]; then
    echo '{"pluginId": "i-have-adhd@i-have-adhd"}'
fi
EOF
cat >"${TEMP}/bin/claude" <<'EOF'
#!/usr/bin/env bash
if [[ "${FAKE_CLAUDE_AGENT_PLUGIN:-false}" == true && "$*" == 'plugin list' ]]; then
    echo 'agent-skills@portable-agent-skills'
fi
if [[ "${FAKE_ADHD_PLUGIN:-false}" == true && "$*" == 'plugin list' ]]; then
    echo 'i-have-adhd@i-have-adhd'
fi
EOF
cat >"${TEMP}/bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
    '-C '*\ 'rev-parse HEAD') printf '%s\n' "${FAKE_GIT_COMMIT}" ;;
    '-C '*\ 'checkout --detach '*) exit 0 ;;
    '-C '*\ 'diff --quiet HEAD -- skills LICENSE-APACHE LICENSE-CC-BY-4.0') [[ "${FAKE_GIT_DIRTY:-false}" != true ]] ;;
    'clone https://github.com/NVIDIA/skills.git '*) cp -R "${FAKE_NVIDIA_REPO}/." "$3/" ;;
    *) printf 'unexpected fake git invocation: %s\n' "$*" >&2; exit 1 ;;
esac
EOF
chmod +x "${TEMP}/bin/"* "${TEMP}/bundle/install-nvidia.sh" "${TEMP}/bundle/scripts/bootstrap.sh"
export PATH="${TEMP}/bin:${PATH}"
export HOME="${TEMP}/home"
export CODEX_HOME="${TEMP}/codex"
export CLAUDE_CONFIG_DIR="${TEMP}/claude"
export AI_AGENT_SOURCE_ROOT="${TEMP}/sources"
export FAKE_GIT_COMMIT="${commit}"
export FAKE_NVIDIA_REPO="${TEMP}/fixture-source"
installer="${TEMP}/bundle/install-nvidia.sh"
bootstrap="${TEMP}/bundle/scripts/bootstrap.sh"

# Default and explicit NVIDIA runs plan the complete catalog without touching the user environment.
output="$("${installer}" --target both)"
[[ "$(grep -c '^\[dry-run\] link ' <<<"${output}")" -eq 834 ]] || fail 'dry-run did not plan all 417 skills for both agents'
grep -Fq 'git clone https://github.com/NVIDIA/skills.git' <<<"${output}"
for target in codex claude; do
    output="$("${bootstrap}" --target "${target}")"
    grep -Fq 'complete: NVIDIA 417-skill catalog' <<<"${output}"
    output="$("${bootstrap}" --target "${target}" --with-nvidia)"
    grep -Fq 'complete: NVIDIA 417-skill catalog' <<<"${output}"
    output="$("${bootstrap}" --target "${target}" --without-nvidia)"
    if grep -Fq 'complete: NVIDIA' <<<"${output}"; then
        fail '--without-nvidia still installed NVIDIA skills'
    fi
done
for path in "${HOME}" "${CODEX_HOME}" "${CLAUDE_CONFIG_DIR}" "${AI_AGENT_SOURCE_ROOT}"; do
    [[ ! -e "${path}" ]] || fail "dry-run created external files: ${path}"
done

# Simulate a future same-name entry without editing the project's real manifests.
printf '%s\n' "${first}" >>"${TEMP}/bundle/manifests/agent-skills.txt"
for target in codex claude; do
    output="$("${bootstrap}" --target "${target}")"
    grep -Fq "prefer NVIDIA: skip baseline skill ${first}" <<<"${output}"
    if grep -Fq "/agent-skills/skills/${first}" <<<"${output}"; then
        fail 'same-name baseline skill was still installed'
    fi
    if [[ "${target}" == claude ]]; then
        grep -Fq 'plugin commands are not included' <<<"${output}"
        if grep -Fq 'plugin install agent-skills@' <<<"${output}"; then
            fail 'Claude installed the complete conflicting agent-skills plugin'
        fi
    fi
done
expect_failure 'existing Claude plugin' env FAKE_CLAUDE_AGENT_PLUGIN=true "${bootstrap}" --target claude --apply
[[ ! -e "${AI_AGENT_SOURCE_ROOT}" && ! -e "${CLAUDE_CONFIG_DIR}" ]] || fail 'Claude plugin conflict was detected after installing NVIDIA'
printf '%s\n' "${first}" >"${TEMP}/bundle/manifests/nvidia-skills.txt"
printf '%s\n' karpathy-guidelines >>"${TEMP}/bundle/manifests/nvidia-skills.txt"
output="$("${bootstrap}" --target codex)"
grep -Fq 'prefer NVIDIA: skip baseline skill karpathy-guidelines' <<<"${output}"
printf '%s\n' i-have-adhd >>"${TEMP}/bundle/manifests/nvidia-skills.txt"
for target in codex claude; do
    output="$("${bootstrap}" --target "${target}")"
    grep -Fq 'prefer NVIDIA: skip baseline skill i-have-adhd' <<<"${output}"
    if grep -Fq 'i-have-adhd@i-have-adhd' <<<"${output}"; then
        fail 'same-name i-have-adhd plugin was still installed'
    fi
    expect_failure "existing ${target} plugin i-have-adhd" env FAKE_ADHD_PLUGIN=true "${bootstrap}" --target "${target}" --apply
done
cp "${ROOT}/manifests/nvidia-skills.txt" "${TEMP}/bundle/manifests/nvidia-skills.txt"

# A pinned local source and fake git keep all apply tests offline and outside real HOME.
directories=("${FAKE_NVIDIA_REPO}/.git")
for name in "${skills[@]}"; do directories+=("${FAKE_NVIDIA_REPO}/skills/${name}"); done
mkdir -p "${directories[@]}"
for name in "${skills[@]}"; do printf '# %s\n' "${name}" >"${FAKE_NVIDIA_REPO}/skills/${name}/SKILL.md"; done
printf 'Apache license fixture\n' >"${FAKE_NVIDIA_REPO}/LICENSE-APACHE"
printf 'CC BY license fixture\n' >"${FAKE_NVIDIA_REPO}/LICENSE-CC-BY-4.0"
mkdir -p "${AI_AGENT_SOURCE_ROOT}"
cp -R "${FAKE_NVIDIA_REPO}" "${AI_AGENT_SOURCE_ROOT}/nvidia-skills"

expect_failure 'manifest expects' env FAKE_GIT_COMMIT=0000000000000000000000000000000000000000 "${installer}" --apply
[[ ! -e "${CODEX_HOME}" ]] || fail 'wrong source pin installed skills'
expect_failure 'modified tracked skill or license files' env FAKE_GIT_DIRTY=true "${installer}" --dry-run
[[ ! -e "${CODEX_HOME}" ]] || fail 'modified source installed skills'
mv "${AI_AGENT_SOURCE_ROOT}/nvidia-skills/skills/${last}/SKILL.md" "${TEMP}/saved-skill"
expect_failure 'missing NVIDIA skill' "${installer}" --apply
[[ ! -e "${CODEX_HOME}" ]] || fail 'missing late source skill allowed partial installation'
mv "${TEMP}/saved-skill" "${AI_AGENT_SOURCE_ROOT}/nvidia-skills/skills/${last}/SKILL.md"

# A conflict at the end of the second target must prevent changes to the first target.
mkdir -p "${CLAUDE_CONFIG_DIR}/skills/${last}"
printf 'existing different skill\n' >"${CLAUDE_CONFIG_DIR}/skills/${last}/SKILL.md"
expect_failure 'refusing to overwrite' "${installer}" --target both --apply
expect_failure 'refusing to overwrite' "${installer}" --target both --dry-run
[[ ! -e "${CODEX_HOME}" && ! -e "${CLAUDE_CONFIG_DIR}/skills/${first}" ]] || fail 'late conflict allowed partial installation'
grep -Fxq 'existing different skill' "${CLAUDE_CONFIG_DIR}/skills/${last}/SKILL.md"

output="$("${installer}" --target codex --apply)"
grep -Fq 'complete: NVIDIA 417-skill catalog for codex (apply)' <<<"${output}"
for name in "${skills[@]}"; do
    [[ -f "${CODEX_HOME}/skills/${name}/SKILL.md" ]] || fail "catalog skill was not installed: ${name}"
done
"${installer}" --target codex --apply >/dev/null

# Exercise cloning into a temporary path, then verify the successful checkout retains licenses.
AI_AGENT_SOURCE_ROOT="${TEMP}/cloned-sources" CODEX_HOME="${TEMP}/cloned-codex" \
    "${installer}" --apply >/dev/null
[[ -f "${TEMP}/cloned-sources/nvidia-skills/LICENSE-APACHE" && \
   -f "${TEMP}/cloned-sources/nvidia-skills/LICENSE-CC-BY-4.0" ]] || fail 'source checkout did not retain licenses'
printf 'NVIDIA integration tests passed\n'
