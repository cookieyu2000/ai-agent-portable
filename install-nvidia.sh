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

validation_repo="${repo_path}"
temp_path=""
if [[ ! -e "${repo_path}" && ! -L "${repo_path}" ]]; then
    if [[ "${MODE}" == dry-run ]]; then
        log "[dry-run] git clone ${url} ${repo_path}"
        log "[dry-run] git -C ${repo_path} checkout --detach ${pinned_commit}"
        validation_repo=""
    else
        mkdir -p "${SOURCE_ROOT}"
        temp_path="$(mktemp -d "${repo_path}.tmp.XXXXXX")"
        cleanup() {
            [[ -n "${temp_path}" && -d "${temp_path}" && ! -L "${temp_path}" ]] || return 0
            local parent expected_parent basename
            parent="$(cd "$(dirname "${temp_path}")" && pwd -P)"
            expected_parent="$(cd "${SOURCE_ROOT}" && pwd -P)"
            basename="${temp_path##*/}"
            # Delete only this clone's checked temporary directory under SOURCE_ROOT.
            if [[ "${parent}" == "${expected_parent}" && "${basename}" == nvidia-skills.tmp.* ]]; then
                rm -rf -- "${parent}/${basename}"
            fi
        }
        trap cleanup EXIT
        git clone "${url}" "${temp_path}"
        git -C "${temp_path}" checkout --detach "${pinned_commit}"
        validation_repo="${temp_path}"
    fi
fi

if [[ -n "${validation_repo}" ]]; then
    [[ -d "${validation_repo}/.git" ]] || fail "source path is not a Git checkout: ${validation_repo}"
    actual_commit="$(git -C "${validation_repo}" rev-parse HEAD)"
    [[ "${actual_commit}" == "${pinned_commit}" ]] ||
        fail "NVIDIA source is at ${actual_commit}; manifest expects ${pinned_commit}; not changing it"
    git -C "${validation_repo}" diff --quiet HEAD -- skills LICENSE-APACHE LICENSE-CC-BY-4.0 ||
        fail "NVIDIA source has modified tracked skill or license files: ${validation_repo}"
    for name in "${skills[@]}"; do
        [[ -f "${validation_repo}/skills/${name}/SKILL.md" ]] ||
            fail "missing NVIDIA skill at pinned commit: ${name}"
    done
    for license in LICENSE-APACHE LICENSE-CC-BY-4.0; do
        [[ -f "${validation_repo}/${license}" ]] || fail "missing NVIDIA license: ${license}"
    done
fi

destination_root_for() {
    case "$1" in
        codex) printf '%s/skills' "${CODEX_HOME:-${HOME}/.codex}" ;;
        claude) printf '%s/skills' "${CLAUDE_CONFIG_DIR:-${HOME}/.claude}" ;;
    esac
}

preflight_for() {
    local agent="$1" destination_root source_path destination name ancestor
    destination_root="$(destination_root_for "${agent}")"
    ancestor="${destination_root}"
    while [[ ! -e "${ancestor}" && ! -L "${ancestor}" ]]; do
        ancestor="$(dirname "${ancestor}")"
    done
    [[ -d "${ancestor}" ]] || fail "skill root ancestor is not a directory: ${ancestor}"
    for name in "${skills[@]}"; do
        source_path="${repo_path}/skills/${name}"
        destination="${destination_root}/${name}"
        if [[ -L "${destination}" ]]; then
            [[ "$(readlink "${destination}")" == "${source_path}" ]] ||
                fail "existing NVIDIA skill link points elsewhere: ${destination}"
        elif [[ -e "${destination}" ]]; then
            [[ -n "${validation_repo}" ]] ||
                fail "cannot compare existing skill without the pinned NVIDIA source: ${destination}"
            [[ -d "${destination}" ]] &&
                diff -qr "${validation_repo}/skills/${name}" "${destination}" >/dev/null ||
                fail "different skill already exists, refusing to overwrite: ${destination}"
        fi
    done
}

# Check every target before creating any skill, including the second target of --target both.
case "${TARGET}" in
    codex) preflight_for codex ;;
    claude) preflight_for claude ;;
    both) preflight_for codex; preflight_for claude ;;
esac

if [[ -n "${temp_path}" ]]; then
    [[ ! -e "${repo_path}" && ! -L "${repo_path}" ]] || fail "NVIDIA source path appeared during installation: ${repo_path}"
    mv -- "${temp_path}" "${repo_path}"
    temp_path=""
    validation_repo="${repo_path}"
    trap - EXIT
fi

install_for() {
    local agent="$1" destination_root source_path destination name
    destination_root="$(destination_root_for "${agent}")"
    if [[ "${MODE}" == apply ]]; then
        mkdir -p "${destination_root}"
    fi
    for name in "${skills[@]}"; do
        source_path="${repo_path}/skills/${name}"
        destination="${destination_root}/${name}"
        if [[ "${MODE}" == dry-run ]]; then
            log "[dry-run] link ${source_path} -> ${destination}"
        elif [[ -L "${destination}" ]]; then
            [[ "$(readlink "${destination}")" == "${source_path}" ]] ||
                fail "existing NVIDIA skill link points elsewhere: ${destination}"
            log "ok: NVIDIA skill already installed: ${destination}"
        elif [[ -e "${destination}" ]]; then
            [[ -d "${destination}" ]] && diff -qr "${source_path}" "${destination}" >/dev/null ||
                fail "different skill already exists, refusing to overwrite: ${destination}"
            log "ok: NVIDIA skill already installed: ${destination}"
        else
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
log "licenses: ${repo_path}/LICENSE-APACHE and ${repo_path}/LICENSE-CC-BY-4.0"
log "complete: NVIDIA ${#skills[@]}-skill catalog for ${TARGET} (${MODE})"
