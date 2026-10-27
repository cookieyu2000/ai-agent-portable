# NVIDIA Agent Skills (optional)

This project pins the **source repository** `NVIDIA/skills` in `manifests/sources.tsv` and selects a small subset via `manifests/nvidia-skills.txt`. There is **no Node.js or npx dependency**. We intentionally **do not vendor** the entire upstream catalog into this repository; it is fetched to `${HOME}/src/ai-agent-sources/nvidia-skills` on `--apply`. A pinned source commit makes rebuilding reproducible.

## Linux / WSL / Git Bash (Bash install)

Run from the repository root:

```bash
./install-codex.sh --with-nvidia --dry-run
./install-codex.sh --with-nvidia --apply
```

To install the curated NVIDIA subset into both agent homes:

```bash
./install-all.sh --with-nvidia --dry-run
./install-all.sh --with-nvidia --apply
```

The existing behavior without `--with-nvidia` is unchanged. Bash installation creates symlinks (`~/.codex/skills/<name>` or `~/.claude/skills/<name>`) to the selected directories, preserving all `SKILL.md`, `references/`, and `scripts/` content. On Windows use **native PowerShell** instead of Git Bash symlinks, since Windows symlink privileges and filesystem behavior differ.

To install NVIDIA skills without installing existing baseline or plugins:

```bash
./install-nvidia.sh --target both --dry-run
./install-nvidia.sh --target both --apply
```

## Windows PowerShell 5.1+ (native; requires Git for Windows only)

```powershell
# First clone this portable repository, then from its root:
.\install-nvidia.ps1 -Target Codex              # preview, no filesystem changes
.\install-nvidia.ps1 -Target Codex -Apply       # install selected skills
.\install-nvidia.ps1 -Target Both -Apply        # install for Codex and Claude
```

The PowerShell installer clones the pinned NVIDIA source, then **copies** the complete selected skill directories to the agent's global skill home. This avoids Windows symlink/developer-mode requirements. Existing identical copies are accepted; conflicting directories are rejected without overwriting. Changing the source pin does **not** automatically replace old skill copies—review and migrate those explicitly.

You can set `AI_AGENT_SOURCE_ROOT`, `CODEX_HOME`, and `CLAUDE_CONFIG_DIR` to override defaults for both installers.

## Adding or changing skills

1. Confirm that a skill exists as `skills/<name>/SKILL.md` in the pinned NVIDIA commit.
2. Add one exact name to `manifests/nvidia-skills.txt` (no automatic whole-catalog installation).
3. Run `./tests/run_all.sh` and dry-run before applying.
4. To upgrade NVIDIA, review its upstream changes first; update the SHA in `manifests/sources.tsv` on a separate change. Existing source checkouts at a different SHA are not automatically reset or pulled. On Windows, installed copies are not overwritten.

## Boundaries and safety

- The source repository is cloned only at `--apply`; no credentials are copied.
- A Skill is **guidance, not the SDK, model weights, CUDA toolkit, driver, or hardware**. Prerequisites still apply.
- Upstream materials are third-party and may have skill-specific licenses; preserve their license notices.
- Do not run unreviewed scripts from downloaded skills against production machines or robots.
- The native Windows installer works with PowerShell and Git for Windows, while `install-all.sh` is a Bash entry point. On Windows, this script only installs **NVIDIA** selections, not the rest of the existing Bash-managed baseline.
