#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="dry-run"
TARGET=""
SOURCE_ROOT="${AI_AGENT_SOURCE_ROOT:-${HOME}/src/ai-agent-sources}"
CODEX_CONFIG_ROOT="${CODEX_HOME:-${HOME}/.codex}"
CLAUDE_CONFIG_ROOT="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"

usage() {
    echo "Usage: $0 --target codex|claude [--dry-run|--apply]"
}

log() {
    printf '%s\n' "$*"
}

run() {
    if [[ "${MODE}" == "dry-run" ]]; then
        printf '[dry-run]'
        printf ' %q' "$@"
        printf '\n'
        return
    fi
    "$@"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

source_record() {
    local requested_name="$1"
    awk -F '\t' -v name="${requested_name}" \
        '$1 == name { print $2 "\t" $3 "\t" $4 }' \
        "${BUNDLE_ROOT}/manifests/sources.tsv"
}

ensure_repo() {
    local name="$1"
    local output_variable="$2"
    local record url commit destination current_commit

    record="$(source_record "${name}")"
    [[ -n "${record}" ]] || fail "source manifest entry not found: ${name}"
    IFS=$'\t' read -r url commit destination <<<"${record}"
    local repository_path="${SOURCE_ROOT}/${destination}"

    if [[ ! -e "${repository_path}" ]]; then
        run mkdir -p "${SOURCE_ROOT}"
        run git clone "${url}" "${repository_path}"
        run git -C "${repository_path}" checkout --detach "${commit}"
        printf -v "${output_variable}" '%s' "${repository_path}"
        return
    fi

    [[ -d "${repository_path}/.git" ]] ||
        fail "source path exists but is not a Git repository: ${repository_path}"

    current_commit="$(git -C "${repository_path}" rev-parse HEAD)"
    [[ "${current_commit}" == "${commit}" ]] ||
        fail "${repository_path} is at ${current_commit}; expected ${commit}. Refusing to change it."

    log "ok: source already pinned: ${name} (${commit:0:12})"
    printf -v "${output_variable}" '%s' "${repository_path}"
}

ensure_symlink() {
    local source_path="$1"
    local destination_path="$2"

    if [[ -L "${destination_path}" ]]; then
        [[ "$(readlink "${destination_path}")" == "${source_path}" ]] ||
            fail "existing link points elsewhere: ${destination_path}"
        log "ok: link already installed: ${destination_path}"
        return
    fi

    [[ ! -e "${destination_path}" ]] ||
        fail "destination already exists and will not be overwritten: ${destination_path}"
    run mkdir -p "$(dirname "${destination_path}")"
    run ln -s "${source_path}" "${destination_path}"
}

install_bundled_skill() {
    local skill_name="$1"
    local config_root="$2"
    local source_path="${BUNDLE_ROOT}/skills/${skill_name}"
    local destination_path="${config_root}/skills/${skill_name}"

    if [[ -d "${destination_path}" && ! -L "${destination_path}" ]]; then
        if diff -qr "${source_path}" "${destination_path}" >/dev/null; then
            log "ok: bundled skill already installed: ${skill_name}"
            return
        fi
        fail "different skill already exists: ${destination_path}"
    fi

    [[ ! -L "${destination_path}" ]] ||
        fail "symbolic link already exists at bundled skill destination: ${destination_path}"
    run mkdir -p "${config_root}/skills"
    run cp -R "${source_path}" "${destination_path}"
}

codex_plugin_installed() {
    codex plugin list --json 2>/dev/null |
        grep -F "\"pluginId\": \"$1\"" >/dev/null
}

ensure_codex_plugin() {
    local plugin_id="$1"
    if [[ "${MODE}" == "dry-run" ]]; then
        run codex plugin add "${plugin_id}"
        return
    fi
    if codex_plugin_installed "${plugin_id}"; then
        log "ok: Codex plugin already installed: ${plugin_id}"
        return
    fi
    run codex plugin add "${plugin_id}"
}

codex_marketplace_installed() {
    codex plugin marketplace list --json 2>/dev/null |
        grep -F "\"name\": \"$1\"" >/dev/null
}

ensure_codex_marketplace() {
    local marketplace_name="$1"
    local marketplace_source="$2"
    if [[ "${MODE}" == "dry-run" ]]; then
        run codex plugin marketplace add "${marketplace_source}"
        return
    fi
    if codex_marketplace_installed "${marketplace_name}"; then
        log "ok: Codex marketplace already configured: ${marketplace_name}"
        return
    fi
    run codex plugin marketplace add "${marketplace_source}"
}

claude_plugin_installed() {
    claude plugin list 2>/dev/null | grep -F "$1" >/dev/null
}

ensure_claude_plugin() {
    local plugin_id="$1"
    if [[ "${MODE}" == "dry-run" ]]; then
        run claude plugin install "${plugin_id}"
        return
    fi
    if claude_plugin_installed "${plugin_id}"; then
        run claude plugin update "${plugin_id}"
        return
    fi
    run claude plugin install "${plugin_id}"
}

claude_marketplace_installed() {
    claude plugin marketplace list 2>/dev/null | grep -F "$1" >/dev/null
}

ensure_claude_marketplace() {
    local marketplace_name="$1"
    local marketplace_source="$2"
    if [[ "${MODE}" == "dry-run" ]]; then
        run claude plugin marketplace add "${marketplace_source}"
        return
    fi
    if claude_marketplace_installed "${marketplace_name}"; then
        log "ok: Claude marketplace already configured: ${marketplace_name}"
        return
    fi
    run claude plugin marketplace add "${marketplace_source}"
}

install_codex() {
    local agent_skills_path adhd_path skill_name
    require_command codex
    require_command git

    ensure_repo agent-skills agent_skills_path
    ensure_repo i-have-adhd adhd_path

    while IFS= read -r skill_name; do
        [[ -n "${skill_name}" ]] || continue
        ensure_symlink \
            "${agent_skills_path}/skills/${skill_name}" \
            "${CODEX_CONFIG_ROOT}/skills/${skill_name}"
    done <"${BUNDLE_ROOT}/manifests/agent-skills.txt"

    install_bundled_skill karpathy-guidelines "${CODEX_CONFIG_ROOT}"
    ensure_codex_plugin github@openai-curated
    ensure_codex_plugin hugging-face@openai-curated
    ensure_codex_marketplace i-have-adhd "${adhd_path}"
    ensure_codex_plugin i-have-adhd@i-have-adhd
}

install_claude() {
    local agent_skills_path adhd_path
    require_command claude
    require_command git

    ensure_repo agent-skills agent_skills_path
    ensure_repo i-have-adhd adhd_path

    ensure_claude_marketplace addy-agent-skills "${agent_skills_path}"
    ensure_claude_plugin agent-skills@addy-agent-skills
    ensure_claude_marketplace i-have-adhd "${adhd_path}"
    ensure_claude_plugin i-have-adhd@i-have-adhd
    install_bundled_skill karpathy-guidelines "${CLAUDE_CONFIG_ROOT}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            [[ $# -ge 2 ]] || fail "--target requires a value"
            TARGET="$2"
            shift 2
            ;;
        --dry-run)
            MODE="dry-run"
            shift
            ;;
        --apply)
            MODE="apply"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

case "${TARGET}" in
    codex)
        install_codex
        ;;
    claude)
        install_claude
        ;;
    *)
        usage
        fail "--target must be codex or claude"
        ;;
esac

log "complete: ${TARGET} bootstrap (${MODE})"
if [[ "${MODE}" == "apply" ]]; then
    log "restart ${TARGET} before using the installed skills"
fi
