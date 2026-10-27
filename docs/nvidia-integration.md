# NVIDIA Agent Skills 整合

此專案預設納入固定版本的 **417 個 NVIDIA skills**，清單見
[manifests/nvidia-skills.txt](../manifests/nvidia-skills.txt)。來源固定為
[`NVIDIA/skills@b28d346437cf378402b19a730cd55cec516c77ff`](https://github.com/NVIDIA/skills/tree/b28d346437cf378402b19a730cd55cec516c77ff)，
由 [sources.tsv](../manifests/sources.tsv) 管理。

各平台完整安裝、驗證與更新步驟見 [README 安裝指南](../README.md#prerequisites)；
全部 444 個 portable skills 的用途與逐項固定來源 citation 見
[完整技能目錄](./skill-catalog.md)。

完整清單已依該版本的 `skills/*/SKILL.md` 與官方
[metadata.json](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/.github/scripts/marketplace/metadata.json)
查核，共 417 個目錄，沒有重複。Repository 保存 manifest，不 vendor 上游 catalog；
安裝入口不需要 Node.js 或 npx，僅於 apply 時取得固定版本來源。

## Bash：Linux／WSL

從 repository 根目錄執行：

```bash
./install-all.sh --dry-run
./install-all.sh --apply
```

預設為 **417 個 NVIDIA skills ＋ 27 個通用技能，共 444 個不重複 portable skills**，
並按各平台的 plugin manifest 安裝 plugins。只安裝一個 agent 可使用
`./install-codex.sh` 或 `./install-claude.sh`。

`--with-nvidia` 保留為相容旗標，效果與預設相同。只安裝原有通用基線：

```bash
./install-all.sh --without-nvidia --dry-run
./install-all.sh --without-nvidia --apply
```

只安裝全部 NVIDIA skills，不安裝通用基線或 plugins：

```bash
bash ./install-nvidia.sh --target both --dry-run
bash ./install-nvidia.sh --target both --apply
```

Bash 將完整 skill 目錄連結至 `~/.codex/skills/<directory>` 或
`~/.claude/skills/<directory>`；`SKILL.md`、`references/`、`scripts/` 與來源授權
保留於完整 checkout。Windows 若只需要 NVIDIA，可使用下方原生 PowerShell 入口，
避免 symbolic link 權限差異；完整 444 項請依
[README 的 Windows Git Bash 步驟](../README.md#windows-full) 準備 native symlinks。

## Windows：PowerShell 5.1+ 與 Git for Windows

從 repository 根目錄執行：

```powershell
.\install-nvidia.ps1 -Target Both          # 預覽兩個 agent；不修改使用者環境
.\install-nvidia.ps1 -Target Both -Apply   # 安裝兩個 agent 的全部 417 個 NVIDIA skills
.\install-nvidia.ps1 -Target Codex -Apply  # 只安裝到 Codex
.\install-nvidia.ps1 -Target Claude -Apply # 只安裝到 Claude
```

未傳入 `-Apply` 一律為 dry-run。此入口只安裝 NVIDIA skills，其餘 27 個通用技能與
plugins 仍由 Bash bootstrap 管理。

PowerShell 先取得固定版本來源，再預檢所有選定 targets 的既有 skill、link 與授權
目的地；全部檢查通過後才開始複製。每個 skill 會保留完整目錄，無須 Windows
Developer Mode 或 symbolic link 權限。已存在且內容相同的目錄可重複執行；
不同內容、不同來源的 link 或其他衝突會停止，且不覆寫既有項目。

根目錄授權 `LICENSE-APACHE` 與 `LICENSE-CC-BY-4.0` 另複製至各 agent 的
`<config>/licenses/nvidia-skills/<SHA>/`；各 skill 自帶的授權隨原目錄保留。

兩種安裝方式皆支援以下環境變數：

| 變數 | 預設位置 |
|---|---|
| `AI_AGENT_SOURCE_ROOT` | `${HOME}/src/ai-agent-sources` |
| `CODEX_HOME` | `${HOME}/.codex` |
| `CLAUDE_CONFIG_DIR` | `${HOME}/.claude` |

## 同名與功能重疊

目前 417 個 NVIDIA 目錄名與原有 27 個通用技能沒有交集，YAML `name` 也沒有交集，
所以全部保留。新安裝清單若出現同名項目，優先選 NVIDIA 來源；既有不同內容的 skill
或指向不同來源的 link 仍拒絕覆寫，需人工比較與處理。

同一任務有多個相近技能時，只有在 NVIDIA skill 的產品、任務與先決條件相符時
才優先使用 NVIDIA。一般 API contracts、前端、Git、TDD 或規劃仍採用通用技能。
例如 `mcore-testing` 適用 Megatron-LM，`compute-sanitizer-diagnose-cuda-bugs`
適用 CUDA correctness；兩者不取代一般專案的測試與除錯技能。

Manifest 使用來源目錄名。上游有 32 個 YAML `name` 與目錄不同：31 個
`bionemo-*` 使用去除 `bionemo-` 前綴的名稱，`ovnewton-usage` 使用
`using-ovnewton`。因此 agent 顯示的名稱可能與安裝目錄不同。

完整清單包含 `nvflare-shared`，與其他 NVFlare skills 一起安裝，確保
`../nvflare-shared/` 的共用 references 與 assets 能正確解析。

## 更新來源版本

1. 先檢視 NVIDIA 上游變更，再更新 `manifests/sources.tsv` 的固定 SHA。
2. 重新列出該版本全部 `skills/*/SKILL.md`，與官方 metadata 比對後更新完整 manifest。
3. 確認目錄名、YAML `name`、同名優先順序、技能適用範圍與共用資源。
4. 執行 `bash -n`、`./tests/run_all.sh` 與 dry-run，再執行 apply。

既有 source checkout 若不在固定 SHA，安裝會停止，不會自動 reset、pull 或切換版本。
Windows 已安裝的不同內容複本不會因來源 SHA 更新而自動替換，需要人工遷移。

## 來源與執行範圍

NVIDIA 的 [README 授權說明](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/README.md#license)
將文件／skills 列為 CC-BY-4.0、source code 列為 Apache-2.0；各檔案或 skill
若附有個別授權，依原始通知保留。來源與授權資訊另見 [THIRD_PARTY.md](../THIRD_PARTY.md)。

安裝 skill 取得的是操作指引與隨附資源。CUDA toolkit、SDK、模型、driver、hardware
及各產品所需服務仍須依對應 skill 的先決條件準備。安裝入口不複製登入憑證或私人環境資料。
