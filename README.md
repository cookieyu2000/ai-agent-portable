# AI Agent Portable

將目前使用的 Codex 與 Claude Code skills／plugins 以可重建方式保存。這個
repository 不保存 plugin cache 或登入憑證；新裝置透過來源 manifest 重新安裝，
connector 則重新授權。

## 新裝置安裝

先安裝 `git`、Codex CLI 與 Claude Code，再 clone 此 repository。

```bash
git clone https://github.com/cookieyu2000/ai-agent-portable.git
cd ai-agent-portable
```

先預覽，不產生任何外部變更：

```bash
./install-all.sh --dry-run
```

確認輸出後執行：

```bash
./install-all.sh --apply
```

也可以只執行 `./install-codex.sh` 或 `./install-claude.sh`。

預設會把外部來源 clone 至：

```text
${HOME}/src/ai-agent-sources/
```

若要使用其他位置：

```bash
AI_AGENT_SOURCE_ROOT=/absolute/path ./install-all.sh --apply
```

## 安全行為

- `--dry-run` 是預設值。
- 不覆寫既有 `~/.codex/skills/<name>`。
- 同名 symbolic link 指向不同來源時會停止。
- 已存在的 source repository 若不是 manifest 記錄的 commit，會停止，不會執行
  `git reset`、`git pull` 或強制切換。
- 不複製 `~/.codex/config.toml`、`~/.claude/settings.json` 或任何 credentials。

## 安裝內容

Codex：

- Codex 內建 skills：由 Codex 安裝本身提供。
- `agent-skills`：clone 固定 commit，建立 `~/.codex/skills/` symbolic links。
- `karpathy-guidelines`：從此 repository 複製。
- GitHub、Hugging Face 與 `i-have-adhd` plugins。

Claude Code：

- `agent-skills@addy-agent-skills`
- `i-have-adhd@i-have-adhd`

需要人工處理：

- Gmail、Google Calendar 與其他 connectors 必須在新裝置重新授權。
- 專案自己的 `AGENTS.md` 應保存在各專案 Git repository。
- 若新裝置已有同名但不同內容的 skill，先人工比較再決定保留哪一份。

## 驗證

```bash
./verify.sh
./tests/test_bootstrap.sh
```

安裝後另外執行：

```bash
codex plugin list
claude plugin list
```

Codex 使用 `$i-have-adhd`；Claude Code 使用 `/i-have-adhd`。
