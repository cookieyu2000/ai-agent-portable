#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="dry-run"
WITH_NVIDIA=true
SKIP_HUGGING_FACE=false
CODEX_GITHUB_PLUGIN="github@openai-curated"
TARGET=""
SOURCE_ROOT="${AI_AGENT_SOURCE_ROOT:-${HOME}/src/ai-agent-sources}"
CODEX_CONFIG_ROOT="${CODEX_HOME:-${HOME}/.codex}"
CLAUDE_CONFIG_ROOT="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
PYTHON_COMMAND="${PYTHON_COMMAND:-python3}"
CODEX_INSTALLED_PLUGINS=()
CODEX_MARKETPLACES=()
CODEX_AGENT_SKILLS_PATH=""
CODEX_ADHD_PATH=""

usage() {
    echo "Usage: $0 --target codex|claude [--dry-run|--apply] [--with-nvidia|--without-nvidia] [--skip-hugging-face] [--github-plugin ID]"
    echo "  --skip-hugging-face  Skip the Codex Hugging Face plugin; continue other plugins."
    echo "  --github-plugin ID   Select an exact Codex GitHub plugin ID (default: github@openai-curated)."
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

prefer_nvidia() {
    [[ "${WITH_NVIDIA}" == true ]] &&
        grep -Fxq -- "$1" "${BUNDLE_ROOT}/manifests/nvidia-skills.txt"
}

skip_baseline_skill() {
    if prefer_nvidia "$1"; then
        log "prefer NVIDIA: skip baseline skill $1"
        return 0
    fi
    return 1
}

claude_agent_skills_overlap() {
    local skill_name
    while IFS= read -r skill_name || [[ -n "${skill_name}" ]]; do
        [[ -n "${skill_name}" && "${skill_name}" != \#* ]] || continue
        if prefer_nvidia "${skill_name}"; then
            return 0
        fi
    done <"${BUNDLE_ROOT}/manifests/agent-skills.txt"
    return 1
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

    if skip_baseline_skill "${skill_name}"; then
        return
    fi

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

install_hallmark() {
    if skip_baseline_skill hallmark; then
        return
    fi
    PYTHON_COMMAND="${PYTHON_COMMAND}" "${BUNDLE_ROOT}/install-optional.sh" \
        --package hallmark --target "${TARGET}" "--${MODE}" \
        --source-root "${SOURCE_ROOT}" \
        --codex-home "${CODEX_CONFIG_ROOT}" \
        --claude-home "${CLAUDE_CONFIG_ROOT}"
}

codex_plugin_installed() {
    local plugin
    for plugin in "${CODEX_INSTALLED_PLUGINS[@]}"; do
        [[ "${plugin}" != "$1" ]] || return 0
    done
    return 1
}

preflight_codex_plugins() {
    require_command "${PYTHON_COMMAND}"
    local record url commit destination snapshot kind identifier plugin_snapshot marketplace_snapshot
    local arguments=()
    record="$(source_record i-have-adhd)"
    [[ -n "${record}" ]] || fail "source manifest entry not found: i-have-adhd"
    IFS=$'\t' read -r url commit destination <<<"${record}"
    CODEX_ADHD_PATH="${SOURCE_ROOT}/${destination}"
    [[ "${SKIP_HUGGING_FACE}" != true ]] || arguments+=(--skip-hugging-face)
    if prefer_nvidia i-have-adhd; then
        arguments+=(--skip-adhd)
    fi
    plugin_snapshot="$(codex plugin list --available --json)" ||
        fail "codex plugin list --available --json failed; check the CLI version, network and account, then retry. No installation was started."
    marketplace_snapshot="$(codex plugin marketplace list --json)" ||
        fail "codex plugin marketplace list --json failed; check the CLI version, network and account, then retry. No installation was started."
    snapshot="$(printf '%s\036%s' "${plugin_snapshot}" "${marketplace_snapshot}" |
        "${PYTHON_COMMAND}" "${BUNDLE_ROOT}/scripts/codex_plugins.py" \
        preflight --adhd-source "${CODEX_ADHD_PATH}" --github-plugin "${CODEX_GITHUB_PLUGIN}" \
        "${arguments[@]}")" || exit 1
    while IFS=$'\t' read -r kind identifier; do
        case "${kind}" in
            plugin) CODEX_INSTALLED_PLUGINS+=("${identifier}") ;;
            marketplace) CODEX_MARKETPLACES+=("${identifier}") ;;
        esac
    done <<<"${snapshot}"
    log "ok: Codex plugin preflight (${MODE})"
    if [[ "${SKIP_HUGGING_FACE}" == true ]]; then
        log "skip: hugging-face@openai-curated (--skip-hugging-face); other plugins remain selected"
    fi
}

prepare_codex_sources() {
    ensure_repo agent-skills CODEX_AGENT_SKILLS_PATH
    if ! prefer_nvidia i-have-adhd; then
        ensure_repo i-have-adhd CODEX_ADHD_PATH
        if [[ "${MODE}" == apply || -e "${CODEX_ADHD_PATH}" ]]; then
            "${PYTHON_COMMAND}" "${BUNDLE_ROOT}/scripts/codex_plugins.py" \
                validate-local "${CODEX_ADHD_PATH}"
        else
            log "[dry-run] validate local i-have-adhd plugin after fetching its pinned source, before installing skills"
        fi
    fi
}

ensure_codex_plugin() {
    local plugin_id="$1"
    if codex_plugin_installed "${plugin_id}"; then
        log "ok: Codex plugin already installed: ${plugin_id}"
        return
    fi
    run codex plugin add "${plugin_id}" ||
        fail "Codex plugin installation failed: ${plugin_id}. Earlier successful steps were preserved; fix the reported error and rerun with the same options to continue."
    if [[ "${MODE}" == apply ]]; then
        CODEX_INSTALLED_PLUGINS+=("${plugin_id}")
    fi
}

codex_marketplace_installed() {
    local marketplace
    for marketplace in "${CODEX_MARKETPLACES[@]}"; do
        [[ "${marketplace}" != "$1" ]] || return 0
    done
    return 1
}

ensure_codex_marketplace() {
    local marketplace_name="$1"
    local marketplace_source="$2"
    if codex_marketplace_installed "${marketplace_name}"; then
        log "ok: Codex marketplace already configured: ${marketplace_name}"
        return
    fi
    run codex plugin marketplace add "${marketplace_source}" ||
        fail "Codex marketplace registration failed: ${marketplace_name}. Earlier successful steps were preserved; fix the reported error and rerun with the same options to continue."
    if [[ "${MODE}" == apply ]]; then
        CODEX_MARKETPLACES+=("${marketplace_name}")
    fi
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
        log "ok: Claude plugin already installed: ${plugin_id}"
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

prepare_portable_claude_marketplace() {
    local agent_skills_path="$1"
    local output_variable="$2"
    local marketplace_root
    local manifest_source
    local manifest_destination

    marketplace_root="${SOURCE_ROOT}/claude-marketplaces/portable-agent-skills"
    manifest_source="${BUNDLE_ROOT}/claude-marketplaces/portable-agent-skills/.claude-plugin/marketplace.json"
    manifest_destination="${marketplace_root}/.claude-plugin/marketplace.json"

    if [[ -f "${manifest_destination}" ]]; then
        diff -q "${manifest_source}" "${manifest_destination}" >/dev/null ||
            fail "different marketplace manifest already exists: ${manifest_destination}"
        log "ok: portable Claude marketplace manifest already installed"
    else
        [[ ! -e "${manifest_destination}" ]] ||
            fail "marketplace manifest path is not a regular file: ${manifest_destination}"
        run mkdir -p "${marketplace_root}/.claude-plugin"
        run cp "${manifest_source}" "${manifest_destination}"
    fi

    ensure_symlink \
        "${agent_skills_path}" \
        "${marketplace_root}/agent-skills"
    printf -v "${output_variable}" '%s' "${marketplace_root}"
}

ensure_claude_agent_skills() {
    local agent_skills_path="$1"
    local marketplace_path

    if claude_agent_skills_overlap; then
        log "prefer NVIDIA: install remaining Claude agent skills individually; plugin commands are not included"
        local skill_name
        while IFS= read -r skill_name || [[ -n "${skill_name}" ]]; do
            [[ -n "${skill_name}" && "${skill_name}" != \#* ]] || continue
            if skip_baseline_skill "${skill_name}"; then
                continue
            fi
            ensure_symlink \
                "${agent_skills_path}/skills/${skill_name}" \
                "${CLAUDE_CONFIG_ROOT}/skills/${skill_name}"
        done <"${BUNDLE_ROOT}/manifests/agent-skills.txt"
        return
    fi

    if [[ "${MODE}" == "apply" ]] &&
        claude_plugin_installed agent-skills@addy-agent-skills; then
        log "ok: compatible legacy Claude plugin already installed: agent-skills@addy-agent-skills"
        return
    fi

    prepare_portable_claude_marketplace \
        "${agent_skills_path}" \
        marketplace_path
    ensure_claude_marketplace portable-agent-skills "${marketplace_path}"
    ensure_claude_plugin agent-skills@portable-agent-skills
}

install_codex() {
    local skill_name

    while IFS= read -r skill_name; do
        [[ -n "${skill_name}" ]] || continue
        if skip_baseline_skill "${skill_name}"; then
            continue
        fi
        ensure_symlink \
            "${CODEX_AGENT_SKILLS_PATH}/skills/${skill_name}" \
            "${CODEX_CONFIG_ROOT}/skills/${skill_name}"
    done <"${BUNDLE_ROOT}/manifests/agent-skills.txt"

    install_bundled_skill karpathy-guidelines "${CODEX_CONFIG_ROOT}"
    install_bundled_skill backend-api-contracts "${CODEX_CONFIG_ROOT}"
    ensure_codex_plugin "${CODEX_GITHUB_PLUGIN}"
    if [[ "${SKIP_HUGGING_FACE}" != true ]]; then
        ensure_codex_plugin hugging-face@openai-curated
    fi
    if ! skip_baseline_skill i-have-adhd; then
        ensure_codex_marketplace i-have-adhd "${CODEX_ADHD_PATH}"
        ensure_codex_plugin i-have-adhd@i-have-adhd
    fi
}

install_claude() {
    local agent_skills_path adhd_path
    require_command claude
    require_command git

    ensure_repo agent-skills agent_skills_path
    if ! prefer_nvidia i-have-adhd; then
        ensure_repo i-have-adhd adhd_path
    fi

    ensure_claude_agent_skills "${agent_skills_path}"
    if ! skip_baseline_skill i-have-adhd; then
        ensure_claude_marketplace i-have-adhd "${adhd_path}"
        ensure_claude_plugin i-have-adhd@i-have-adhd
    fi
    install_bundled_skill karpathy-guidelines "${CLAUDE_CONFIG_ROOT}"
    install_bundled_skill backend-api-contracts "${CLAUDE_CONFIG_ROOT}"
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
        --with-nvidia)
            WITH_NVIDIA=true
            shift
            ;;
        --without-nvidia)
            WITH_NVIDIA=false
            shift
            ;;
        --skip-hugging-face)
            SKIP_HUGGING_FACE=true
            shift
            ;;
        --github-plugin)
            [[ $# -ge 2 && "$2" != --* ]] || fail "--github-plugin requires a plugin@marketplace value"
            CODEX_GITHUB_PLUGIN="$2"
            [[ "${CODEX_GITHUB_PLUGIN}" =~ ^github@[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] ||
                fail "--github-plugin requires an exact github@marketplace ID"
            shift 2
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

[[ "${TARGET}" == codex || "${TARGET}" == claude ]] || {
    usage
    fail "--target must be codex or claude"
}

require_command "${TARGET}"
require_command git
require_command "${PYTHON_COMMAND}"
if [[ "${TARGET}" == codex ]]; then
    preflight_codex_plugins
fi
if prefer_nvidia i-have-adhd; then
    if { [[ "${TARGET}" == codex ]] && codex_plugin_installed i-have-adhd@i-have-adhd; } ||
        { [[ "${TARGET}" == claude ]] && claude_plugin_installed i-have-adhd@i-have-adhd; }; then
        fail "existing ${TARGET} plugin i-have-adhd@i-have-adhd includes a skill preferred from NVIDIA; remove it explicitly or use --without-nvidia. No existing plugin was changed."
    fi
fi
if [[ "${TARGET}" == claude ]] && claude_agent_skills_overlap; then
    for plugin_id in agent-skills@addy-agent-skills agent-skills@portable-agent-skills; do
        if claude_plugin_installed "${plugin_id}"; then
            fail "existing Claude plugin ${plugin_id} includes skills preferred from NVIDIA; remove it explicitly or use --without-nvidia. No existing plugin was changed."
        fi
    done
fi
if [[ "${TARGET}" == codex ]]; then
    prepare_codex_sources
fi
install_hallmark
if [[ "${WITH_NVIDIA}" == true ]]; then
    bash "${BUNDLE_ROOT}/install-nvidia.sh" --target "${TARGET}" "--${MODE}"
fi

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
