# 選配技能與遠端辦公工具

本頁實際可安裝的項目是 **Hallmark** 與 **Codync**。原有 444 個基線 skills 與
`install-codex.sh`／`install-claude.sh` 的行為不變；Hallmark 另加 1 個選配 skill，
Codync 是獨立執行工具，不計入 skill 數量。

| 套件 | 固定版本 | 安裝結果 | 下一步 |
|---|---|---|---|
| Hallmark | 2.0.0，固定 Git SHA | 將完整 skill、references、scripts 與授權複製到選定 agent | [設計與瀏覽器驗證](hallmark.md) |
| Codync | 2.43.1，固定 release 與 SHA256 | 將 host binary 與授權放到獨立版本目錄 | [手機配對、進度與排程](codync.md) |

來源、版本、平台與下載 checksum 由
[optional-sources.json](../manifests/optional-sources.json) 管理。
安裝器不呼叫上游安裝腳本，不啟動背景服務、不配對手機，也不設定 agent 登入、
排程、hooks 或自動更新。這些步驟由各工作主機依 Codync 指南明確啟用。

## Linux／WSL／macOS

需要 Python 3.10+、Git 與網路。從 repository 根目錄執行：

```bash
# 預覽兩項：不連網、不建立檔案
./install-optional.sh --package all --target codex --dry-run

# 安裝 Hallmark skill 與 Codync host
./install-optional.sh --package all --target codex --apply
```

只裝一項時改用 `--package hallmark` 或 `--package codync`。
Hallmark 支援 `--target codex|claude|both`；Codync host 每個使用者安裝一份，
不因 target=both 啟動兩個服務。

## Windows PowerShell

原生 Windows 可安裝 Hallmark，需 Python 3.10+ 與 Git：

```powershell
.\install-optional.ps1 -Package Hallmark -Target Codex
.\install-optional.ps1 -Package Hallmark -Target Codex -Apply
```

要同時裝到兩個 agent，使用 `-Target Both`。
Codync 2.43.1 的獨立 host release 只有 Linux／macOS，Windows host 隨上游桌面版
發佈。因此原生 Windows 選 `Codync` 或 `All` 會在安裝前拒絕，不會只完成一半；
請使用 [Codync 官方桌面版](https://github.com/leepokai/Codync/releases/tag/v2.43.1)，
或在執行 agents 的 WSL 內使用上面的 Bash 流程。Windows 與 WSL 是分開的環境。

## 路徑與重跑

| 內容 | 預設位置 |
|---|---|
| 固定來源 checkout | `~/src/ai-agent-sources/<package>-<完整 SHA>/` |
| Codex Hallmark | `<CODEX_HOME>/skills/hallmark/`，未設定時用 `~/.codex/` |
| Claude Hallmark | `<CLAUDE_CONFIG_DIR>/skills/hallmark/`，未設定時用 `~/.claude/` |
| Codync binary | `~/.local/share/ai-agent-portable/runtimes/codync/2.43.1/codync-host` |
| Codync 啟用後的私人資料 | 由 Codync 管理，通常在 `~/.codync/`；不放入此 repository |

可用 `--source-root`／`--runtime-root`／`--codex-home`／`--claude-home`
自訂絕對路徑；來源也接受 `AI_AGENT_SOURCE_ROOT`。
PowerShell 對應 `-SourceRoot`／`-RuntimeRoot`／`-CodexHome`／`-ClaudeHome`。

沒有 `--apply`／`-Apply` 一律只預覽。相同內容可重跑；不同內容、symlink
或被修改的來源會停止，不覆寫現有 skill／runtime。來源與下載在 repository 外，
來源 checkout 和 runtime 版本目錄應保留；Codync 服務啟用後會使用該 binary 路徑。
更新版本時先檢視上游差異，再修改固定 manifest，依指南遷移服務；不直接
`git pull` 或覆蓋舊版本。

## 其他先前評估的項目

Graphify、HyperFrames、ai-memory 仍是先前評估的候選項目，**目前沒有安裝器實作，
也不包含在 `--package all`**。先前本頁列出的這三項安裝指令沒有對應檔案，
已更正為上面可執行的 Hallmark／Codync 流程。未新增其他 memory service 或 T3 Code。

各套件的來源與授權見 [THIRD_PARTY.md](../THIRD_PARTY.md)。
