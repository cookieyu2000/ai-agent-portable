#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/manifests/nvidia-skills.txt"
SOURCES="${SCRIPT_DIR}/manifests/sources.tsv"
SOURCE_ROOT="${AI_AGENT_SOURCE_ROOT:-${HOME}/src/ai-agent-sources}"
TARGET="codex"
MODE="dry-run"

usage() {
    echo "Usage: $0 [--target codex|claude|both] [--dry-run|--apply]"
}
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

while (($#)); do
    case "$1" in
        --target)
            (($# >= 2)) || fail "--target requires an argument"
            TARGET="$2"; shift 2 ;;
        --dry-run) MODE="dry-run"; shift ;;
        --apply) MODE="apply"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unsupported argument: $1" ;;
    esac
done
[[ "${TARGET}" == codex || "${TARGET}" == claude || "${TARGET}" == both ]] || fail "unknown target: ${TARGET}"
command -v git >/dev/null || fail "git is required; npx is not needed"
[[ -f "${MANIFEST}" && -f "${SOURCES}" ]] || fail "NVIDIA manifest or source manifest missing"

source_record="$(awk -F '\t' '$1 == "nvidia-skills" { print $2 "\t" $3 "\t" $4 }' "${SOURCES}")"
[[ -n "${source_record}" ]] || fail "nvidia-skills not found in manifests/sources.tsv"
IFS=$'\t' read -r url pinned_commit dirname <<<"${source_record}"
[[ "${url}" == https://github.com/NVIDIA/skills.git ]] || fail "unexpected NVIDIA source URL"
[[ "${pinned_commit}" =~ ^[0-9a-f]{40}$ ]] || fail "invalid NVIDIA commit SHA"
[[ "${dirname}" == nvidia-skills ]] || fail "unexpected NVIDIA destination path"
repo_path="${SOURCE_ROOT}/${dirname}"

skills=()
declare -A seen=()
while IFS= read -r name || [[ -n "${name}" ]]; do
    [[ -z "${name}" || "${name}" == \#* ]] && continue
    [[ "${name}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid NVIDIA skill name: ${name}"
    [[ ! -v "seen[$name]" ]] || fail "duplicate NVIDIA skill: ${name}"
    seen["${name}"]=1
    skills+=("${name}")
done < "${MANIFEST}"
((${#skills[@]} > 0)) || fail "No NVIDIA skills in manifest"

if [[ "${MODE}" == dry-run ]]; then
    if [[ ! -e "${repo_path}" ]]; then
        log "[dry-run] git clone ${url} ${repo_path}"
        log "[dry-run] git -C ${repo_path} checkout --detach ${pinned_commit}"
    else
        log "[dry-run] verify pinned NVIDIA checkout: ${repo_path} (${pinned_commit})"
    fi
else
    if [[ ! -e "${repo_path}" ]]; then
        mkdir -p "${SOURCE_ROOT}"
        temp_path="${repo_path}.tmp.$$"
        [[ ! -e "${temp_path}" ]] || fail "temporary clone path already exists: ${temp_path}"
        cleanup() { [[ ! -e "${temp_path:-}" ]] || rm -rf -- "${temp_path}"; }
        trap cleanup EXIT
        git clone "${url}" "${temp_path}"
        git -C "${temp_path}" checkout --detach "${pinned_commit}"
        mv -- "${temp_path}" "${repo_path}"
        trap - EXIT
    fi
    [[ -d "${repo_path}/.git" ]] || fail "source path is not a Git checkout: ${repo_path}"
    actual_commit="$(git -C "${repo_path}" rev-parse HEAD)"
    [[ "${actual_commit}" == "${pinned_commit}" ]] ||
        fail "NVIDIA source is at ${actual_commit}; manifest expects ${pinned_commit}; not changing it"
    for name in "${skills[@]}"; do
        [[ -f "${repo_path}/skills/${name}/SKILL.md" ]] ||
            fail "missing NVIDIA skill at pinned commit: ${name}"
    done
fi

install_for() {
    local agent="$1" destination_root source_path destination name
    case "${agent}" in
        codex) destination_root="${CODEX_HOME:-${HOME}/.codex}/skills" ;;
        claude) destination_root="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/skills" ;;
    esac
    for name in "${skills[@]}"; do
        source_path="${repo_path}/skills/${name}"
        destination="${destination_root}/${name}"
        if [[ "${MODE}" == dry-run ]]; then
            log "[dry-run] link ${source_path} -> ${destination}"
        elif [[ -L "${destination}" ]]; then
            [[ "$(readlink "${destination}")" == "${source_path}" ]] ||
                fail "existing NVIDIA skill link points elsewhere: ${destination}"
            log "ok: already linked ${destination}"
        elif [[ -e "${destination}" ]]; then
            fail "Skill already exists, refusing to overwrite: ${destination}"
        else
            mkdir -p "${destination_root}"
            ln -s "${source_path}" "${destination}"
            log "installed: ${agent}/${name}"
        fi
    done
}

case "${TARGET}" in
    codex) install_for codex ;;
    claude) install_for claude ;;
    both) install_for codex; install_for claude ;;
esac
log "complete: NVIDIA ${#skills[@]}-skill selection for ${TARGET} (${MODE})"
