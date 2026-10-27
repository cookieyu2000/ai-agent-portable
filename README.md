# AI Agent Portable

[![Validate](https://github.com/cookieyu2000/ai-agent-portable/actions/workflows/validate.yml/badge.svg)](https://github.com/cookieyu2000/ai-agent-portable/actions/workflows/validate.yml)

在不同設備上重建 Codex／Claude Code 的 skills 與 plugins。此 repository 保存可攜技能、固定來源 manifest、安裝 scripts 與文件；外部技能在明確 apply 時取得。登入、connectors 授權與個人設定由每台設備自行處理。

目前固定的 portable 清單為 **444 個不重複 skills**：

| 來源 | 數量 | 安裝清單／來源 citation |
|---|---:|---|
| NVIDIA 全部 skills | 417 | [manifest](./manifests/nvidia-skills.txt) · [固定版本 catalog](https://github.com/NVIDIA/skills/tree/b28d346437cf378402b19a730cd55cec516c77ff/skills) |
| `addyosmani/agent-skills` | 24 | [manifest](./manifests/agent-skills.txt) · [固定版本來源](https://github.com/addyosmani/agent-skills/tree/7829ffd90d973b6325f5f12f1b1226dcace74443/skills) |
| `i-have-adhd` | 1 | [固定版本來源](https://github.com/ayghri/i-have-adhd/tree/07684c4ab625dd7d1ea6e99e065f60bc0ac6a1ba) |
| 本專案 bundled skills | 2 | [karpathy-guidelines](./skills/karpathy-guidelines/SKILL.md) · [backend-api-contracts](./skills/backend-api-contracts/SKILL.md) |
| **合計** | **444** | NVIDIA 417 ＋ [通用基線 27](./manifests/common-skills.txt) |

全部名稱、用途摘要與逐項來源列於本文的[完整技能目錄](#skill-catalog)，亦可單獨閱讀 [docs/skill-catalog.md](./docs/skill-catalog.md)。這是安裝 manifest 的數量；Codex 內建技能、GitHub／Hugging Face plugins 的技能與 Claude commands 另計。[SKILLS.md](./SKILLS.md) 保留的是舊環境 82 項盤點，不是目前 444 項安裝清單。

> 文件與官方安裝指引核對日期：2026-10-27。上游 skills 依固定 SHA 計數，不能用今天線上 catalog 的數量替代。此 repository 不自動 commit、push 或設定 remote。

## 目錄

- [每台新設備的準備工作](#prerequisites)
- [取得正確版本的專案](#get-project)
- [Windows：完整安裝到 Codex](#windows-full)
- [Windows：PowerShell 只安裝 NVIDIA](#windows-nvidia)
- [Linux／WSL：完整安裝到 Codex](#linux-wsl)
- [macOS：完整安裝到 Codex](#macos)
- [其他安裝組合與自訂位置](#options)
- [安裝後驗證與 Codex 載入位置](#verification)
- [NVIDIA 優先規則](#nvidia-first)
- [更新、重跑與衝突處理](#maintenance)
- [來源、版本與授權](#sources)
- [完整技能目錄：444 個](#skill-catalog)

<a id="prerequisites"></a>
## 每台新設備的準備工作

完整安裝 Codex skills 需要 **Git、Bash 5 與 Codex CLI**。只安裝到 Codex 不需要 Claude Code。Bash scripts 使用 associative arrays 等功能，請使用 Bash 5；[GNU Bash arrays 手冊](https://www.gnu.org/software/bash/manual/html_node/Arrays.html) 說明 `declare -A` 的用途。

| 項目 | 何時需要 | 官方安裝／說明 |
|---|---|---|
| Git | 所有安裝入口 | [Git 安裝](https://git-scm.com/install/) |
| Codex CLI | `install-codex.sh`，即使平常使用 IDE extension 仍需 CLI 執行 plugin 安裝 | [OpenAI Codex CLI](https://learn.chatgpt.com/docs/codex/cli) |
| Bash 5 | 完整 Bash bootstrap | Windows 用 [Git Bash](https://gitforwindows.org/)；macOS 見下方 Homebrew 步驟 |
| Claude Code CLI | 只有 `install-claude.sh`／`install-all.sh` 需要 | [Claude Code 官方安裝](https://code.claude.com/docs/en/setup) |
| Python 3 | `list-skills.sh` 與 Python 測試；不是 skills 安裝的必要條件 | [Python downloads](https://www.python.org/downloads/) |
| `rg` | 開發者執行 `verify.sh`／完整測試 | [ripgrep 官方專案](https://github.com/BurntSushi/ripgrep) |

安裝 Codex CLI 請依官方頁面選擇作業系統的安裝方式。每台設備啟動一次 `codex` 完成登入，然後在**即將用來安裝的同一個 terminal** 檢查：

```bash
git --version
bash --version
codex --version
codex plugin --help
codex plugin marketplace --help
```

若找不到 `codex`，先修正 CLI 的安裝與 `PATH`，不要以另一個使用者或不同 Codex profile 繼續。若沒有 `plugin` subcommand，先依 [OpenAI CLI reference](https://learn.chatgpt.com/docs/cli/reference#codex-plugin) 確認／更新相容版本。Scripts 不直接編輯 `config.toml`；plugin 的安裝與設定由 Codex CLI 管理。

登入憑證應留在各設備的 credential store。不要把整個 `~/.codex` 或 `~/.claude` 複製進此 repository；官方 [Authentication](https://learn.chatgpt.com/docs/auth) 說明本機登入資料的儲存方式。

<a id="get-project"></a>
## 取得正確版本的專案

每台設備取得本專案一次。以下命令可在 Git Bash、Linux／WSL、macOS terminal 或 PowerShell 執行：

```bash
git clone https://github.com/cookieyu2000/ai-agent-portable.git
cd ai-agent-portable
```

**Clone 只能取得已推送的內容。** 若原設備上的 417 項整合尚未發布，請先自行檢視、commit／push，再於新設備 clone；或直接把更新後的本專案目錄複製到新設備。不要把來源 checkout、plugin cache、sessions、history 或登入資料一起收進專案。

在開始前，確認新設備收到的是完整 417 項 NVIDIA 清單：

```bash
awk '/^[a-z0-9][a-z0-9-]*$/ { n++ } END { print n }' manifests/nvidia-skills.txt
```

預期輸出 `417`。PowerShell 可使用：

```powershell
@(Get-Content .\manifests\nvidia-skills.txt | Where-Object { $_ -match '^[a-z0-9][a-z0-9-]*$' }).Count
```

以下所有安裝命令都從 `ai-agent-portable` 根目錄執行。請在每台設備、每個需要使用 skills 的帳號／執行環境各安裝一次。

<a id="windows-full"></a>
## Windows：完整安裝到 Codex

這條路徑安裝 **444 個 portable skills 與 Codex plugins**。使用 **Git Bash app**，不在 PowerShell 直接執行 `.sh`；PowerShell 裡的 `bash` 可能指向 WSL，並不代表 Git Bash。

### 1. 準備 Git Bash 與 symbolic links

1. 安裝 [Git for Windows](https://git-scm.com/install/windows)，從開始選單開啟 **Git Bash**。
2. 在 Windows Settings 搜尋 **Developer Mode** 並啟用。若設備由組織管理且無法啟用，改用下方的 PowerShell NVIDIA-only 入口，或在 WSL 內安裝。
3. 來源 checkout 與安裝目的地使用支援 Windows symbolic links 的檔案系統，例如 NTFS／ReFS；避免將 linked source 放在不支援連結的外接磁碟。
4. 在 Git Bash 確認前述 `git`、Bash 5 與 `codex` 命令皆可使用。

Git Bash 的 `ln -s` 預設可能改成複製；完整安裝命令使用 `MSYS=winsymlinks:nativestrict`，讓無法建立真正連結時直接報錯。依據：[Git for Windows symbolic links](https://gitforwindows.org/symbolic-links.html)、[MSYS2 symlinks](https://www.msys2.org/docs/symlinks/)、[Microsoft Developer Mode](https://learn.microsoft.com/en-us/windows/advanced-settings/developer-mode)。

### 2. 確認安裝帳號與位置

在 Git Bash 檢查：

```bash
printf 'HOME=%s\nCODEX_HOME=%s\n' "$HOME" "${CODEX_HOME:-$HOME/.codex}"
```

`HOME` 應對應正在使用 Codex 的同一個 Windows 使用者。若平常設定了自訂 `CODEX_HOME`，此 terminal 也要使用相同的**絕對路徑**，參考[自訂位置](#options)。

### 3. 預覽，再明確安裝

```bash
MSYS=winsymlinks:nativestrict ./install-codex.sh --dry-run
MSYS=winsymlinks:nativestrict ./install-codex.sh --apply
```

第一條只顯示計畫，不 clone、不建立安裝檔案。確認目標與來源正確後，再執行第二條。沒有 `--apply` 也會保持 dry-run。

完成後繼續[安裝後驗證](#verification)。保留來源 checkout；這條路徑的 NVIDIA 與 `agent-skills` 使用 symbolic links。

<a id="windows-nvidia"></a>
## Windows：PowerShell 只安裝 NVIDIA

如果目前只需要全部 NVIDIA skills，這條原生入口安裝 **417 個 NVIDIA skills**，使用完整目錄複本，不需要 Developer Mode、Bash、Node.js、npx 或 symbolic link 權限；需要 Git for Windows。這條入口不安裝 27 個通用 skills，也不安裝 Codex plugins。

在專案目錄開啟 PowerShell 5.1+：

```powershell
.\install-nvidia.ps1 -Target Codex
.\install-nvidia.ps1 -Target Codex -Apply
```

第一條預覽；第二條才會 clone 固定來源與複製完整 skill 目錄。授權另保存至 `<CODEX_HOME>/licenses/nvidia-skills/<SHA>/`。

若下載的 script 被標為來自網際網路，先檢視來源與內容；確認後可只解除這個檔案的封鎖，再執行上述命令：

```powershell
Unblock-File -LiteralPath .\install-nvidia.ps1
```

`Unblock-File` 的行為見 [Microsoft PowerShell 文件](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file)。它只處理檔案的網際網路標記，不會解除 `Restricted` execution policy。若自己的設備仍因 execution policy 無法啟動已確認的 script，可只為這次 process 指定 policy：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-nvidia.ps1 -Target Codex
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-nvidia.ps1 -Target Codex -Apply
```

此設定不永久變更 CurrentUser／LocalMachine policy；組織的 Group Policy 仍優先，受管設備依組織規範處理。來源：[Microsoft execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)。

其他目標：

```powershell
.\install-nvidia.ps1 -Target Claude
.\install-nvidia.ps1 -Target Claude -Apply
.\install-nvidia.ps1 -Target Both
.\install-nvidia.ps1 -Target Both -Apply
```

若之後要補齊 Codex 的 27 個通用 skills 與 plugins，在**同一個 Windows 使用者、相同來源與 `CODEX_HOME`** 的 Git Bash，按[Windows 完整安裝](#windows-full)設定後執行：

```bash
MSYS=winsymlinks:nativestrict ./install-codex.sh --without-nvidia --dry-run
MSYS=winsymlinks:nativestrict ./install-codex.sh --without-nvidia --apply
```

這樣保留 NVIDIA 的 PowerShell copies，只補通用基線。不要反向用 PowerShell 入口覆蓋 Git Bash 建立的 NVIDIA links；原生安裝器遇到 reparse points 會停止。

<a id="linux-wsl"></a>
## Linux／WSL：完整安裝到 Codex

先在該環境安裝 Git、Bash 5 與 Codex CLI，取得本專案，然後執行：

```bash
./install-codex.sh --dry-run
./install-codex.sh --apply
```

這會安裝全部 444 個 portable skills 與 Codex plugins。來源預設為 `~/src/ai-agent-sources/`；NVIDIA 與 `agent-skills` 使用連結，安裝後不可移除或隨意搬動來源目錄。

**WSL 與 Windows 原生 Codex 分開看待。** 如果 Codex 在 WSL 內執行，就在該 WSL distribution、該 Linux 帳號安裝並登入 Codex；在 WSL 安裝的 skills 不等於已安裝到 Windows 使用者目錄。Windows 原生 Codex 則使用上方 Windows 步驟。官方說明見 [OpenAI WSL 指引](https://learn.chatgpt.com/docs/windows/wsl)。

<a id="macos"></a>
## macOS：完整安裝到 Codex

本專案需要 Bash 5；不要直接使用不支援此安裝器功能的舊版系統 Bash。已安裝 [Homebrew](https://brew.sh/) 後，在 terminal 執行：

```bash
brew install bash
export PATH="$(brew --prefix bash)/bin:$PATH"
bash --version
```

請確認顯示 Bash 5。`brew --prefix bash` 同時適用 Apple Silicon 與 Intel，無須硬編碼 `/opt/homebrew` 或 `/usr/local`。來源：[Homebrew bash formula](https://formulae.brew.sh/formula/bash)、[Homebrew `--prefix`](https://docs.brew.sh/Manpage)。

接著安裝／確認 Git 與 Codex CLI、取得本專案，再執行：

```bash
./install-codex.sh --dry-run
./install-codex.sh --apply
```

`export PATH=...` 需要與安裝命令在**同一個 terminal session**。只有用新版 Bash 執行最外層檔案還不夠，因為子腳本也會透過 `bash`／`env bash` 找到執行器。之後換新 terminal 重跑時，請再次設定上述 `PATH`，或自行合併至既有 shell 設定，不覆寫原本的設定檔。

<a id="options"></a>
## 其他安裝組合與自訂位置

以下 Bash 範例皆假設已滿足該作業系統前提。Windows Git Bash 請為安裝命令加上 `MSYS=winsymlinks:nativestrict`。

| 需求 | 預覽 | 明確安裝 |
|---|---|---|
| Codex 全部 444 | `./install-codex.sh --dry-run` | `./install-codex.sh --apply` |
| Claude Code 全部 444 | `./install-claude.sh --dry-run` | `./install-claude.sh --apply` |
| Codex 與 Claude Code | `./install-all.sh --dry-run` | `./install-all.sh --apply` |
| Codex 原有 27 個通用 skills | `./install-codex.sh --without-nvidia --dry-run` | `./install-codex.sh --without-nvidia --apply` |
| 只裝 Codex 的 NVIDIA 417 | `bash ./install-nvidia.sh --target codex --dry-run` | `bash ./install-nvidia.sh --target codex --apply` |
| 兩個 agent 只裝 NVIDIA | `bash ./install-nvidia.sh --target both --dry-run` | `bash ./install-nvidia.sh --target both --apply` |

`--with-nvidia` 保留為相容旗標，與目前預設相同。`install-all.sh` 需要同時有 `codex` 與 `claude` CLI；只用 Codex 就使用 `install-codex.sh`。

安裝位置如下；沒有設定環境變數時才使用預設：

| 變數／內容 | 預設位置 | 用途 |
|---|---|---|
| `AI_AGENT_SOURCE_ROOT` | `$HOME/src/ai-agent-sources` | 三個固定版本來源 checkout |
| `CODEX_HOME` | `$HOME/.codex` | 本專案 Codex skills、plugins 與 Codex profile |
| `CLAUDE_CONFIG_DIR` | `$HOME/.claude` | Claude skills 與 plugin 設定 |
| NVIDIA／agent-skills linked skills | `<CODEX_HOME>/skills/<directory>` | 完整目錄連結 |
| bundled skills | `<CODEX_HOME>/skills/<name>` | 本專案的兩個完整複本 |
| `i-have-adhd` | Codex plugin 管理的位置 | 由 plugin 提供一個通用 skill |

**所有 override 都使用絕對路徑**。Bash 自訂來源範例：

```bash
AI_AGENT_SOURCE_ROOT="$HOME/src/ai-agent-sources" ./install-codex.sh --dry-run
AI_AGENT_SOURCE_ROOT="$HOME/src/ai-agent-sources" ./install-codex.sh --apply
```

Windows Git Bash 若使用另一磁碟，可把來源改成 `/d/ai-agent-sources`；要與 PowerShell 共用時，兩邊必須對應到同一個實體目錄。PowerShell 範例：

```powershell
$env:AI_AGENT_SOURCE_ROOT = 'D:\ai-agent-sources'
$env:CODEX_HOME = Join-Path $HOME '.codex'
.\install-nvidia.ps1 -Target Codex
.\install-nvidia.ps1 -Target Codex -Apply
```

`CODEX_HOME` 會影響 Codex profile，不要只是為了變更 skill 資料夾就把它指向一個空白目錄；Codex 本身與安裝命令應使用相同設定。

<a id="verification"></a>
## 安裝後驗證與 Codex 載入位置

### 檢查安裝器與 plugin 結果

完整 Codex 入口成功時，會看到 NVIDIA catalog 與 Codex bootstrap 的完成訊息。接著檢查：

```bash
codex plugin list
codex plugin marketplace list
```

預期有 `github@openai-curated`、`hugging-face@openai-curated` 與 `i-have-adhd@i-have-adhd`。對需要帳號的 connector，仍須在新設備重新授權；skill 檔案存在不代表服務已授權。Plugin 命令依據：[OpenAI CLI reference](https://learn.chatgpt.com/docs/cli/reference#codex-plugin)。

開啟新的 Codex session，在 CLI／IDE extension 輸入 `/skills` 或 `$` 選擇技能，例如 `$deepstream-dev`。如新裝內容尚未出現，重新啟動 Codex。[OpenAI skills 說明](https://learn.chatgpt.com/docs/build-skills#how-chatgpt-and-codex-use-skills)

### 區分本專案安裝位置與新版 Codex discovery

目前 scripts 將本機 skills 安裝到 `<CODEX_HOME>/skills`，預設為 `~/.codex/skills`。官方現行文件列出的 user-scope discovery 位置是 `$HOME/.agents/skills`，且支援 symlinked skill folders。**安裝成功後仍須用 `/skills` 確認實際使用的 Codex client 能載入。** 來源：[OpenAI local skill locations](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills)。

若該 client 已載入這批技能，就不必新增重複路徑。若技能未出現，先確認 profile、目錄與 `SKILL.md`；需要相容連結時，只在 `$HOME/.agents/skills` **尚不存在**的情況下，手動連結既有的 skills 目錄。安裝器不會代做這一步，也不會覆寫現有 `.agents` 內容。

Linux／macOS／WSL 範例（使用預設 `CODEX_HOME`；自訂時調整來源）：

```bash
if [ ! -d "$HOME/.codex/skills" ]; then
    printf 'Missing installed skill directory\n' >&2
elif [ -e "$HOME/.agents/skills" ] || [ -L "$HOME/.agents/skills" ]; then
    printf 'Existing .agents/skills: compare and merge manually; leave it unchanged\n'
else
    mkdir -p "$HOME/.agents"
    ln -s "$HOME/.codex/skills" "$HOME/.agents/skills"
fi
```

Windows 可在 Git Bash 以相同邏輯建立 native symlink，仍須 `MSYS=winsymlinks:nativestrict` 與前述權限；PowerShell 使用者可將既有 skills 目錄逐項合併到官方 discovery 位置，遇同名差異先停止比較。不要把整個 `.codex` 設定目錄搬到 `.agents`，也不要同時載入兩份內容相同的實體 skill。

### 查看 filesystem inventory

已安裝 Python 3 時，從本專案執行：

```bash
./list-skills.sh --platform codex
./list-skills.sh --platform both --format json
```

如 terminal 的 Python 名稱是 `python` 而非 `python3`：

```bash
PYTHON_COMMAND=python ./list-skills.sh --platform codex
```

這是本專案目前掃描 `~/.codex`／`~/.claude` 的 filesystem inventory，可能含內建或 plugin cache 內容，不等於 client 實際公開的技能清單；也不掃描獨立安裝於 `~/.agents/skills` 的項目。不要以 skills 資料夾數量判定是否正好 444，因為 `i-have-adhd` 由 plugin 提供，其他 plugins 與系統技能也會額外出現。輸出 JSON 若要分享，先檢查內容，勿將私人環境盤點自動提交到 repository。

<a id="nvidia-first"></a>
## NVIDIA 優先規則

目前 417 個 NVIDIA skills 與 27 個通用 skills 的目錄名、YAML `name` 沒有交集，所以全部保留。處理同一任務時，若 NVIDIA skill 的產品、任務與先決條件相符，優先選 NVIDIA；一般 API、前端、Git 或 TDD 繼續使用相應通用技能。

例如 `compute-sanitizer-diagnose-cuda-bugs` 用於 CUDA correctness，不取代一般 CPU／Web 除錯；`mcore-testing` 用於 Megatron-Core，不取代所有專案的通用測試工作。

本專案 [AGENTS.md](./AGENTS.md) 已記錄此規則。**安裝 skills 不會把本專案的 AGENTS.md 自動套用到其他專案。** 若希望同一台設備的所有 Codex 專案都有此偏好，請把以下一條規則手動合併到該 profile 的 `<CODEX_HOME>/AGENTS.md`，保留原有內容：

```text
若 NVIDIA skill 的適用範圍涵蓋目前任務，同名或功能雷同的 skill 優先使用 NVIDIA 版本；通用工程 skill 補充未涵蓋的部分，不將產品限定 skill 套用到範圍外。
```

每台設備自行合併；如果已有 `AGENTS.override.md`，要一起確認實際生效的指令來源。全域／專案規則的優先順序依 [OpenAI AGENTS.md 文件](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。本專案不自動覆寫全域規則或個人設定。

<a id="maintenance"></a>
## 更新、重跑與衝突處理

### 重跑與停止條件

- 預設 dry-run；只有明確的 `--apply`／PowerShell `-Apply` 修改使用者環境。
- NVIDIA 入口先檢查選定 targets 的來源、授權與目的地；同內容 NVIDIA copies／同來源 Bash links 可重跑，差異不覆寫。
- 通用技能的 symlink 也須指向原來源；bundled copies 須內容相同。既有 Claude plugin 不會被此 bootstrap 自動 update。
- source checkout 不在固定 SHA，或 NVIDIA 已追蹤的 skill／license 檔案被修改時會停止；不執行 reset、pull 或強制切換。
- 完整 bootstrap 按階段執行；若通用技能或 plugin 階段失敗，先前已成功的 NVIDIA 安裝可能仍保留。`install-all.sh` 也不會回滾前一個 agent。請處理明確錯誤後再重跑。
- 不要刪除或搬動 linked source。也不要用另一個帳號或不同 `HOME` 重跑，期待它更新原帳號的安裝。

### 常見問題

| 現象 | 處理方式 |
|---|---|
| `codex: command not found`／沒有 `plugin` | 在當前 terminal 安裝或更新相容 Codex CLI，確認 `PATH`，再重跑 dry-run |
| Bash arrays／`[[ -v ]]` 語法錯誤 | 使用 Bash 5；macOS 同時調整 `PATH` 讓子腳本找到新版 |
| Windows symbolic link 權限失敗 | 確認 Developer Mode、檔案系統與 native symlink 設定；無法啟用時選 PowerShell NVIDIA-only 或 WSL |
| 目的地已有不同 skill／link | 停止，人工比較來源與內容；自行備份、決定遷移方式後再重跑，安裝器不代刪 |
| source SHA 不符／來源被修改 | 保留既有 checkout，先核對 manifest；新安裝可改用另一個絕對 source root。若已有 linked skills，仍須先人工規劃 links 遷移，不強制重設舊目錄 |
| 安裝成功但 `/skills` 看不到 | 確認實際 client／profile、官方 discovery 路徑與 `SKILL.md`，參考上方相容處理並重啟 |
| `/skills` 顯示數量與 444 不同 | 分清 portable manifest、plugins、系統技能與 client context budget；以 manifest 與逐項來源核對 |
| Plugin marketplace 或授權失敗 | 檢查 network、帳號與 marketplace 名稱；不要把登入資料寫進 manifest，先依錯誤訊息處理 |

### 更新 portable 專案與上游版本

在新 clone 中取得已發布版本即可。若已有工作目錄，先檢視 `git status`、保存自己的變更，再由你決定如何更新；此 bootstrap 不自動 commit、push、設定 remote 或替你合併 Git 變更。

更新本專案不代表自動升級所有上游來源。要升級 NVIDIA／agent-skills／i-have-adhd：

1. 審閱上游變更與授權，更新 [sources.tsv](./manifests/sources.tsv) 的明確 SHA。
2. 核對技能目錄、YAML `name`、相依 references 與同名優先順序，更新對應 manifests。
3. 同步本文與 [完整目錄](./docs/skill-catalog.md) 的名稱、摘要、固定版本 citation 與數量。
4. 執行檢查與 dry-run。遇舊來源／舊 copies 差異，先人工規劃遷移，不自動覆寫。

完整安裝的 GitHub／Hugging Face plugins 從 marketplace 取得；[codex-plugins.txt](./manifests/codex-plugins.txt) 的 `observed_version` 是記錄值，scripts 沒有把遠端 plugin 內容鎖定到這個版本。因此 **skills source SHA 可固定重建，marketplace plugins 不保證逐位元同版本**。

### 開發者驗證

文件檢視與 manifest 核對可執行 `./verify.sh`。修改 scripts 後依 [AGENTS.md](./AGENTS.md) 執行：

```bash
(
    set -e
    for script in install-*.sh list-skills.sh scripts/bootstrap.sh tests/*.sh verify.sh; do
        bash -n "$script"
    done
)
./tests/run_all.sh
```

完整測試需要 Bash 5、Python 3、`rg` 與 Git；有 `pwsh`／`powershell.exe` 時也會執行隔離的 PowerShell regression tests。測試使用臨時 fixture，不安裝到真實 agent HOME。

<a id="sources"></a>
## 來源、版本與授權

外部 skills 版本由 [sources.tsv](./manifests/sources.tsv) 管理；逐項 citation 使用固定 SHA，不使用浮動 `main`：

| 來源 | 固定版本／citation | 用途 |
|---|---|---|
| NVIDIA skills | [`b28d346437cf378402b19a730cd55cec516c77ff`](https://github.com/NVIDIA/skills/tree/b28d346437cf378402b19a730cd55cec516c77ff) · [官方 metadata](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/.github/scripts/marketplace/metadata.json) | 417 個 skills 的名稱、alias、分類與用途依據 |
| agent-skills | [`7829ffd90d973b6325f5f12f1b1226dcace74443`](https://github.com/addyosmani/agent-skills/tree/7829ffd90d973b6325f5f12f1b1226dcace74443) | 24 個通用工程 skills |
| i-have-adhd | [`07684c4ab625dd7d1ea6e99e065f60bc0ac6a1ba`](https://github.com/ayghri/i-have-adhd/tree/07684c4ab625dd7d1ea6e99e065f60bc0ac6a1ba) | 1 個 skill 與 plugin 安裝來源 |
| 本專案 bundled | [karpathy-guidelines](./skills/karpathy-guidelines/SKILL.md) · [backend-api-contracts](./skills/backend-api-contracts/SKILL.md) | 以本專案保存內容為準；沒有可查證的原始上游記錄時不猜外部作者或 URL |
| Codex plugins | [codex-plugins.txt](./manifests/codex-plugins.txt) | GitHub、Hugging Face 與 i-have-adhd 的 plugin IDs／觀測版本 |
| Claude plugins | [claude-plugins.txt](./manifests/claude-plugins.txt) · [本機 marketplace](./claude-marketplaces/portable-agent-skills/.claude-plugin/marketplace.json) | Claude plugin IDs 與本機固定 checkout |

NVIDIA catalog 的雙授權與個別檔案通知見 [官方 LICENSE-APACHE](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/LICENSE-APACHE)、[LICENSE-CC-BY-4.0](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/LICENSE-CC-BY-4.0) 與 [THIRD_PARTY.md](./THIRD_PARTY.md)。Bash 保留完整 source checkout 及授權；PowerShell copies 另保存兩份根授權。

NVIDIA skills 的 manifest 使用來源**目錄名**。其中 32 個 YAML `name` 不同：31 個 `bionemo-*` 去掉前綴，另有 `ovnewton-usage` → `using-ovnewton`；完整目錄逐項標示。NVFlare 的完整集合包含 `nvflare-shared`，其共用 references 隨整套保留。

安裝 skill 取得的是指引與隨附資源，不等於已安裝 CUDA toolkit、SDK、模型、GPU driver 或各產品服務。請依各 skill 的適用範圍與先決條件執行。

<a id="skill-catalog"></a>
## 完整技能目錄：444 個

以下按來源與產品列出全部 444 個 portable skills，包含用途摘要與每項固定來源 citation。摘要為繁體中文整理，不替代來源 SKILL.md 的前提、限制與授權；同一份清單另存於 [docs/skill-catalog.md](./docs/skill-catalog.md)。

<!-- SKILL_CATALOG_START -->

本目錄依本專案的 [common-skills.txt](./manifests/common-skills.txt)、[agent-skills.txt](./manifests/agent-skills.txt)、[nvidia-skills.txt](./manifests/nvidia-skills.txt) 與 [sources.tsv](./manifests/sources.tsv) 整理：**27 個通用 skills + 417 個 NVIDIA skills = 444 個不重複的安裝項目**。這個數字不包含 plugins 額外提供的 skills、Codex 內建 skills 或舊 [SKILLS.md](./SKILLS.md) 的環境盤點快照。

每一列的 identifier 是 manifest 的目錄名稱；若原始 SKILL.md 的 YAML `name` 不同，同行加註。安裝路徑與精確指定技能時須區分這兩者。下列每項外部來源均固定到本專案鎖定的 commit，不會因上游 main 改動而指向別的版本。

用途文字是本專案整理的繁體中文摘要；完整適用範圍、前置條件、限制與執行規則以每列引用的 SKILL.md 為準。若 NVIDIA skill 涵蓋目前任務，同名或功能雷同時優先選 NVIDIA；通用工程 skills 補足其未涵蓋的部分。這項選用規則不會刪除其他 skill，也不會把產品限定流程套用到範圍外的工作。

### 通用基線（27）

#### addyosmani/agent-skills（24）

來源作者 Addy Osmani；固定版本 `7829ffd90d973b6325f5f12f1b1226dcace74443`。授權為 [MIT](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/LICENSE)；Copyright (c) 2025 Addy Osmani。各項引用如下。

| Identifier | 用途摘要 | 原始來源 citation |
|---|---|---|
| `api-and-interface-design` | 設計穩定的 REST／GraphQL API、型別契約與模組介面。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/api-and-interface-design/SKILL.md) |
| `browser-testing-with-devtools` | 使用 Chrome DevTools MCP 檢查真實瀏覽器 DOM、網路與畫面。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/browser-testing-with-devtools/SKILL.md) |
| `ci-cd-and-automation` | 建立 CI／CD、品質閘門、測試 runner 與部署自動化。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/ci-cd-and-automation/SKILL.md) |
| `code-review-and-quality` | 在合併前從多個面向審查程式品質。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/code-review-and-quality/SKILL.md) |
| `code-simplification` | 在維持行為下簡化程式，提高可讀性與可維護性。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/code-simplification/SKILL.md) |
| `context-engineering` | 整理專案規則與 agent 上下文，改善工作品質。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/context-engineering/SKILL.md) |
| `debugging-and-error-recovery` | 以可驗證流程找出測試、建置及執行錯誤的根因。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/debugging-and-error-recovery/SKILL.md) |
| `deprecation-and-migration` | 規劃舊 API、系統與功能的棄用及遷移。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/deprecation-and-migration/SKILL.md) |
| `documentation-and-adrs` | 記錄架構決策、公開 API 與功能所需文件。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/documentation-and-adrs/SKILL.md) |
| `doubt-driven-development` | 以獨立上下文進行對抗性檢查，驗證重要決策。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/doubt-driven-development/SKILL.md) |
| `frontend-ui-engineering` | 建立可存取、響應式且適合正式使用的 UI。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/frontend-ui-engineering/SKILL.md) |
| `git-workflow-and-versioning` | 整理分支、衝突、版本、tag 與 changelog 工作流。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/git-workflow-and-versioning/SKILL.md) |
| `idea-refine` | 發散與收斂想法，釐清假設及可執行方向。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/idea-refine/SKILL.md) |
| `incremental-implementation` | 把跨檔案或大型變更拆成可驗證的小步實作。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/incremental-implementation/SKILL.md) |
| `interview-me` | 透過逐題訪談釐清需求背後的目的與限制。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/interview-me/SKILL.md) |
| `observability-and-instrumentation` | 加入 logs、metrics、tracing 與告警以診斷正式環境。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/observability-and-instrumentation/SKILL.md) |
| `performance-optimization` | 量測並改善前後端、查詢與資料庫效能。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/performance-optimization/SKILL.md) |
| `planning-and-task-breakdown` | 把規格拆成有順序且可實作的工作。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/planning-and-task-breakdown/SKILL.md) |
| `security-and-hardening` | 強化輸入、認證、資料儲存與外部整合安全。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/security-and-hardening/SKILL.md) |
| `shipping-and-launch` | 準備上線檢查、監控、分階段推出與還原策略。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/shipping-and-launch/SKILL.md) |
| `source-driven-development` | 以官方文件及來源佐證實作決策。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/source-driven-development/SKILL.md) |
| `spec-driven-development` | 在實作新功能或重大改動前建立清楚規格。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/spec-driven-development/SKILL.md) |
| `test-driven-development` | 透過測試驅動功能、修錯與行為變更。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/test-driven-development/SKILL.md) |
| `using-agent-skills` | 探索並選用當前任務適用的技能。 | [SKILL.md](https://github.com/addyosmani/agent-skills/blob/7829ffd90d973b6325f5f12f1b1226dcace74443/skills/using-agent-skills/SKILL.md) |

#### ayghri/i-have-adhd（1）

來源作者 Ayoub Ghriss；固定版本 `07684c4ab625dd7d1ea6e99e065f60bc0ac6a1ba`，授權為 [MIT](https://github.com/ayghri/i-have-adhd/blob/07684c4ab625dd7d1ea6e99e065f60bc0ac6a1ba/LICENSE)；Copyright (c) 2026 Ayoub Ghriss。

| Identifier | 用途摘要 | 原始來源 citation |
|---|---|---|
| `i-have-adhd` | 調整回覆順序、步驟與資訊密度，支援需要 ADHD 友善輸出的使用者。 | [SKILL.md](https://github.com/ayghri/i-have-adhd/blob/07684c4ab625dd7d1ea6e99e065f60bc0ac6a1ba/skills/i-have-adhd/SKILL.md) |

#### 本專案 bundled skills（2）

以下直接隨專案保存；本 repository 沒有記錄可核實的原始外部 repository／commit，因此引用本地實際檔案，不推測外部出處。

| Identifier | 用途摘要 | 原始來源 citation |
|---|---|---|
| `backend-api-contracts` | 定義可驗證、可觀測、向後相容的 backend API、驗證與資料隔離契約。 | [本專案 SKILL.md](./skills/backend-api-contracts/SKILL.md) |
| `karpathy-guidelines` | 先釐清假設、保持實作簡單、精準修改並設定可驗證成功條件；檔案標示 MIT。 | [本專案 SKILL.md](./skills/karpathy-guidelines/SKILL.md) |

<details>
<summary>NVIDIA 完整目錄：417 個 skills／53 個產品分類（點此展開）</summary>

### NVIDIA 完整目錄（417）

來源：NVIDIA CORPORATION & AFFILIATES；固定版本 `b28d346437cf378402b19a730cd55cec516c77ff`。數量與下列產品分組依該版本的 [marketplace metadata](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/.github/scripts/marketplace/metadata.json) 核對；identifier 必須同時存在於本專案 [nvidia-skills.txt](./manifests/nvidia-skills.txt)。此處的 417 是本專案鎖定版本數量，不代表 NVIDIA 官網未來的即時總數。

NVIDIA 上游 [授權說明](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/README.md#license) 將文件／skills 列為 [CC-BY-4.0](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/LICENSE-CC-BY-4.0)、原始碼列為 [Apache-2.0](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/LICENSE-APACHE)；Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES。以下繁中用途文字為本專案的翻譯整理摘要，原始內容及其個別授權標示以每項引用為準。

#### Auto Ontology（3）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nvidia-ontology-management` | 在 Auto Ontology 建模及發布詞彙、關係、度量與受治理的語意定義。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvidia-ontology-management/SKILL.md) |
| `nvidia-ontology-query` | 透過 MCP 或 REST 查詢 Auto Ontology，驗證 SQL、結果列與回答依據。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvidia-ontology-query/SKILL.md) |
| `nvidia-ontology-setup` | 部署或修復 Auto Ontology runtime，設定 Helm、Docker Compose 與 MCP 連線。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvidia-ontology-setup/SKILL.md) |

#### BioNeMo Libraries（3）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `bionemo-genomics-workflow-acceleration`<br>YAML name: `genomics-workflow-acceleration` | 將既有基因體流程的步驟改用 Parabricks GPU 加速並比較效能與結果。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-genomics-workflow-acceleration/SKILL.md) |
| `bionemo-nvmolkit-usage`<br>YAML name: `nvmolkit-usage` | 開發或除錯 nvMolKit 的 GPU 分子指紋、相似度、構形與搜尋程式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-nvmolkit-usage/SKILL.md) |
| `bionemo-parabricks`<br>YAML name: `parabricks` | 規劃 Parabricks pbrun 指令、轉換 CPU 工具選項並檢查執行環境。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-parabricks/SKILL.md) |

#### BioNeMo NIMs（13）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `bionemo-boltz2-nim`<br>YAML name: `boltz2-nim` | 使用 Boltz2 NIM 預測生物分子複合體結構與結合親和力。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-boltz2-nim/SKILL.md) |
| `bionemo-diffdock-nim`<br>YAML name: `diffdock-nim` | 使用 DiffDock NIM 預測小分子與蛋白質的對接姿態及信心分數。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-diffdock-nim/SKILL.md) |
| `bionemo-drug-discovery-pipeline`<br>YAML name: `drug-discovery-pipeline` | 串接 GenMol、DiffDock 與 Boltz2，完成分子生成、對接與親和力篩選。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-drug-discovery-pipeline/SKILL.md) |
| `bionemo-evo2-nim`<br>YAML name: `evo2-nim` | 使用 Evo 2 BioNeMo NIM 生成 DNA 序列並分析模型輸出。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-evo2-nim/SKILL.md) |
| `bionemo-genmol-nim`<br>YAML name: `genmol-nim` | 使用 GenMol NIM 與 SAFE 表示法生成及最佳化候選小分子。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-genmol-nim/SKILL.md) |
| `bionemo-molmim-nim`<br>YAML name: `molmim-nim` | 使用 MolMIM NIM 進行分子潛在空間生成、embeddings 擷取與性質最佳化。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-molmim-nim/SKILL.md) |
| `bionemo-msa-search-nim`<br>YAML name: `msa-search-nim` | 使用 ColabFold MSA-Search NIM 搜尋同源序列、產生 MSA 並取得結構模板。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-msa-search-nim/SKILL.md) |
| `bionemo-msa-structure-prediction-pipeline`<br>YAML name: `msa-structure-prediction-pipeline` | 串接 MSA-Search 與 OpenFold3，以序列比對資訊輔助蛋白質結構預測。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-msa-structure-prediction-pipeline/SKILL.md) |
| `bionemo-openfold2-nim`<br>YAML name: `openfold2-nim` | 使用 OpenFold2 NIM，從序列、MSA 與模板預測單體蛋白質結構。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-openfold2-nim/SKILL.md) |
| `bionemo-openfold3-nim`<br>YAML name: `openfold3-nim` | 使用 OpenFold3 NIM 預測蛋白質、配體、核酸及多鏈生物分子複合體。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-openfold3-nim/SKILL.md) |
| `bionemo-proteinmpnn-nim`<br>YAML name: `proteinmpnn-nim` | 使用 ProteinMPNN NIM，依目標蛋白質骨架設計或重新設計序列。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-proteinmpnn-nim/SKILL.md) |
| `bionemo-rfd4-proteina-nim`<br>YAML name: `rfd4-proteina-nim` | 使用 RFD4-Proteina NIM 進行蛋白質結構與序列的聯合設計及獎勵導向搜尋。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-rfd4-proteina-nim/SKILL.md) |
| `bionemo-rfdiffusion-nim`<br>YAML name: `rfdiffusion-nim` | 使用 RFDiffusion NIM 設計蛋白質骨架、結合體及 motif 支架。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-rfdiffusion-nim/SKILL.md) |

#### BioNeMo Open Models（15）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `bionemo-codonfm-embed`<br>YAML name: `codonfm-embed` | 驗證編碼序列資料，擷取 CodonFM／Encodon embeddings 並選擇模型 checkpoint。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-codonfm-embed/SKILL.md) |
| `bionemo-codonfm-finetune`<br>YAML name: `codonfm-finetune` | 以 LoRA、預測頭或完整微調方式，調整公開 CodonFM Encodon 模型的分類與迴歸能力。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-codonfm-finetune/SKILL.md) |
| `bionemo-codonfm-score`<br>YAML name: `codonfm-score` | 準備並執行 CodonFM Encodon 的遮罩密碼子變異評分。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-codonfm-score/SKILL.md) |
| `bionemo-codonfm-setup`<br>YAML name: `codonfm-setup` | 建立公開 CodonFM v1 開發環境並下載支援的 Encodon 模型權重。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-codonfm-setup/SKILL.md) |
| `bionemo-complexa-evaluate-pdbs`<br>YAML name: `complexa-evaluate-pdbs` | 以 Proteina-Complexa CLI 評估 PDB 設計的重摺疊、介面品質及可設計性。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-complexa-evaluate-pdbs/SKILL.md) |
| `bionemo-complexa-sweep`<br>YAML name: `complexa-sweep` | 執行 Proteina-Complexa 參數掃描、組態比較與品質／成本權衡分析。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-complexa-sweep/SKILL.md) |
| `bionemo-complexa-target`<br>YAML name: `complexa-target` | 建立及驗證 Proteina-Complexa 的蛋白質、配體與 motif 設計目標。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-complexa-target/SKILL.md) |
| `bionemo-kermt-add-cmim-pretrain`<br>YAML name: `kermt-add-cmim-pretrain` | 替 grover_base checkpoint 加入 cMIM 元件，接續混合式 KERMT 預訓練。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-kermt-add-cmim-pretrain/SKILL.md) |
| `bionemo-kermt-continue-pretrain`<br>YAML name: `kermt-continue-pretrain` | 使用既有 KERMT checkpoint，在自訂 SMILES 語料上接續預訓練。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-kermt-continue-pretrain/SKILL.md) |
| `bionemo-kermt-embed`<br>YAML name: `kermt-embed` | 從含編碼器的 KERMT checkpoint 擷取分子 embeddings 與有效性資料。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-kermt-embed/SKILL.md) |
| `bionemo-kermt-finetune`<br>YAML name: `kermt-finetune` | 驗證標記 CSV 與模型後，微調 KERMT 分子編碼器。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-kermt-finetune/SKILL.md) |
| `bionemo-kermt-infer`<br>YAML name: `kermt-infer` | 使用已微調的 KERMT checkpoint，對 SMILES CSV 執行分子性質預測。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-kermt-infer/SKILL.md) |
| `bionemo-kermt-monitor`<br>YAML name: `kermt-monitor` | 檢查背景 KERMT 訓練容器、日誌與 epoch／step／loss 進度。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-kermt-monitor/SKILL.md) |
| `bionemo-kermt-pretrain-scratch`<br>YAML name: `kermt-pretrain-scratch` | 從自訂語料建立詞彙表，以隨機初始化的 KERMT 模型開始預訓練。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-kermt-pretrain-scratch/SKILL.md) |
| `bionemo-kermt-setup`<br>YAML name: `kermt-setup` | 檢查 Docker 與 GPU 容器工具，建置 KERMT 映像並執行基本驗證。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/bionemo-kermt-setup/SKILL.md) |

#### Client（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nvidia-app` | 透過 NVIDIA App MCP 檢查驅動、管理及最佳化遊戲與筆電功能。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvidia-app/SKILL.md) |

#### Compute Sanitizer（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `compute-sanitizer-diagnose-cuda-bugs` | 使用 Compute Sanitizer 診斷 CUDA 記憶體錯誤、共享記憶體競爭與同步問題。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/compute-sanitizer-diagnose-cuda-bugs/SKILL.md) |

#### Cosmos（12）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `cdf-anomalygen` | 執行 CDF AnomalyGen 的遮罩配置、微調、缺陷影像生成、評估與偽標記。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-anomalygen/SKILL.md) |
| `cdf-augmentation` | 撰寫 CDF 資料增強組態，呼叫 Cosmos Transfer／Predict、影像編輯與圖轉影片服務。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-augmentation/SKILL.md) |
| `cdf-auto-labeling` | 規劃與執行 CDF 自動標記 cookbook，設定階段、提示詞及容器。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-auto-labeling/SKILL.md) |
| `cdf-autonomous-vehicle-dataset-generation` | 執行自駕資料集生成 Airflow 流程，檢索駕駛片段並生成 Cosmos3-Nano 變體。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-autonomous-vehicle-dataset-generation/SKILL.md) |
| `cdf-curation-and-retrieval` | 使用 Cosmos Curator 與 Dataset Search 整理、去重、標註、嵌入及搜尋影像影片資料。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-curation-and-retrieval/SKILL.md) |
| `cdf-defect-image-generation` | 在 Kubernetes 執行 CDF SMT 缺陷影像 DAG，串接模擬、sim2real 與 AnomalyGen。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-defect-image-generation/SKILL.md) |
| `cdf-event-video-generation` | 在 Kubernetes 或 OSMO 以種子影像生成事件／異常影片及自動標記資料集。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-event-video-generation/SKILL.md) |
| `cdf-image-attribute-augmentation` | 執行 CDF 人物影像屬性與服裝增強，搜尋屬性並取得生成資料。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-image-attribute-augmentation/SKILL.md) |
| `cdf-orchestration-preflight` | 檢查並補足 Linux、Kubernetes／OSMO、GPU 與儲存等 CDF Orchestration 前置條件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-orchestration-preflight/SKILL.md) |
| `cdf-orchestration-setup` | 部署、升級或重新連接 CDF Orchestration Airflow controller 並驗證服務。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-orchestration-setup/SKILL.md) |
| `cdf-orchestration-write-dag` | 為現有流程未涵蓋的 CDF 階段組合建立 Kubernetes DAG 並核對外部規格。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-orchestration-write-dag/SKILL.md) |
| `cdf-video-data-augmentation` | 執行 CDF 影片轉影片增強 Airflow 流程，並自動標記原始與生成影片。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-video-data-augmentation/SKILL.md) |

#### CUDA Tile（7）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `tilegym-adding-cutile-kernel` | 在 TileGym 新增 cuTile operator，完成註冊、實作、測試及 benchmark。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tilegym-adding-cutile-kernel/SKILL.md) |
| `tilegym-converting-cutile-to-julia` | 將 cuTile Python kernel 移植為 cuTile.jl，處理索引、型別與記憶體布局差異。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tilegym-converting-cutile-to-julia/SKILL.md) |
| `tilegym-converting-cutile-to-triton` | 將 cuTile kernel 轉為 Triton，驗證數值、形狀與記憶體存取。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tilegym-converting-cutile-to-triton/SKILL.md) |
| `tilegym-cutile-autotuning` | 建立或除錯 cuTile 自動調校，設定架構參數、搜尋空間與快取流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tilegym-cutile-autotuning/SKILL.md) |
| `tilegym-cutile-python` | 使用 cuTile 的 tile 程式模型撰寫、驗證及最佳化 GPU kernels。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tilegym-cutile-python/SKILL.md) |
| `tilegym-improve-cutile-kernel-perf` | 透過 profiling、IR 比較與參數調整，反覆改善 cuTile kernel 效能。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tilegym-improve-cutile-kernel-perf/SKILL.md) |
| `tilegym-monkey-patch-kernels-to-transformers` | 將 TileGym kernels 整合進 Hugging Face transformers 模型的初始化、forward 與載入流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tilegym-monkey-patch-kernels-to-transformers/SKILL.md) |

#### CUDA-Q（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `cudaq-guide` | 設定 CUDA-Q、選擇模擬或 QPU 執行目標，並撰寫量子 kernel。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cudaq-guide/SKILL.md) |
| `cudaq-importing` | 將 Qiskit 等框架的量子電路移植到 CUDA-Q，保留演算法與驗證結果。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cudaq-importing/SKILL.md) |

#### cuDF（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `accelerated-computing-cudf` | 使用 cuDF、pandas 加速與 dask-cuDF 處理 GPU DataFrame、ETL、彙總及多 GPU 資料工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/accelerated-computing-cudf/SKILL.md) |

#### cuOpt（8）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `cuopt-developer` | 開發、建置、測試與除錯 cuOpt 本體，遵循貢獻及程式風格規範。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cuopt-developer/SKILL.md) |
| `cuopt-install` | 透過 pip、conda 或 Docker 安裝並驗證 cuOpt Python、C 或伺服器版本。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cuopt-install/SKILL.md) |
| `cuopt-multi-objective-exploration` | 反覆求解 cuOpt 單目標問題，建立並解讀多目標 Pareto 前緣。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cuopt-multi-objective-exploration/SKILL.md) |
| `cuopt-numerical-optimization-api` | 使用 cuOpt Python、C 或 CLI API 求解 LP、MILP 與 QP 問題。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cuopt-numerical-optimization-api/SKILL.md) |
| `cuopt-numerical-optimization-formulation` | 將問題描述整理成 LP、MILP 或 QP 的決策變數、限制式及目標函數。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cuopt-numerical-optimization-formulation/SKILL.md) |
| `cuopt-routing-api-python` | 使用 cuOpt Python API 建立與求解 VRP、TSP、PDP 等路線規劃問題。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cuopt-routing-api-python/SKILL.md) |
| `cuopt-server-api-python` | 啟動 cuOpt REST server，並使用 Python 或 curl 呼叫端點。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cuopt-server-api-python/SKILL.md) |
| `portfolio-optimization` | 使用 cuOpt、Mean-CVaR 或 Mean-Variance 方法建立、回測及重新平衡股票組合。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/portfolio-optimization/SKILL.md) |

#### DALI（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `dali-dynamic-mode` | 撰寫、移植或除錯 DALI imperative dynamic mode 的資料處理程式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/dali-dynamic-mode/SKILL.md) |

#### DeepStream SDK（10）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `amc-run-rtsp-calibration` | 透過 AutoMagicCalib REST API 錄製並校準即時 RTSP 攝影機串流。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/amc-run-rtsp-calibration/SKILL.md) |
| `amc-run-sample-calibration` | 執行 AutoMagicCalib 隨附範例資料的完整校準，驗證服務安裝。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/amc-run-sample-calibration/SKILL.md) |
| `amc-run-video-calibration` | 透過 AutoMagicCalib REST API 校準預錄的多攝影機 MP4 資料。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/amc-run-video-calibration/SKILL.md) |
| `amc-setup-calibration-stack` | 使用 Docker Compose 部署 AutoMagicCalib 微服務與網頁介面。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/amc-setup-calibration-stack/SKILL.md) |
| `deepstream-dev` | 使用 Python pyservicemaker 建立 DeepStream 影片分析、推論、追蹤與訊息整合管線。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/deepstream-dev/SKILL.md) |
| `deepstream-generate-pipeline` | 互動式建立 DeepStream／GStreamer 影像影片推論、追蹤及串流管線。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/deepstream-generate-pipeline/SKILL.md) |
| `deepstream-import-vision-model` | 將 Hugging Face 或 NGC 偵測模型匯入 DeepStream，完成匯出、TensorRT 建置及效能報告。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/deepstream-import-vision-model/SKILL.md) |
| `deepstream-profile-pipeline` | 使用 Nsight Systems 量測 DeepStream 管線，依結果調整設定與 FPS。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/deepstream-profile-pipeline/SKILL.md) |
| `deepstream-run-mv3dt` | 設定及執行 DeepStream 多視角 3D 追蹤，整合相機校準、視覺化與 Kafka 資料。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/deepstream-run-mv3dt/SKILL.md) |
| `deepstream-sop` | 建置與評估 DeepStream SOP 微服務，透過事件邊界及 VLM 檢查作業步驟順序。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/deepstream-sop/SKILL.md) |

#### DOCA（51）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `doca-aes-gcm` | 在 BlueField／ConnectX 設定 AES-GCM 加解密、能力查詢與驗證。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-aes-gcm/SKILL.md) |
| `doca-argp` | 建立 DOCA CLI 參數解析、旗標與 JSON 設定。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-argp/SKILL.md) |
| `doca-argus` | 部署 Argus 執行期安全服務並轉送偵測結果至 SIEM。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-argus/SKILL.md) |
| `doca-bare-metal-deployment` | 在主機或 BlueField Arm 裸機啟動、監督與排查 DOCA 程式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-bare-metal-deployment/SKILL.md) |
| `doca-bench` | 以 doca_bench 量測 DOCA 加速器吞吐、延遲與頻寬。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-bench/SKILL.md) |
| `doca-bench-extension` | 開發與除錯自訂 doca-bench 工作負載擴充程式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-bench-extension/SKILL.md) |
| `doca-bf3-deployment` | 透過 RShim／BFB 初始化及驗證 BlueField-3 平台。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-bf3-deployment/SKILL.md) |
| `doca-bf4-deployment` | 透過 BMC、Redfish 與 PLDM 初始化 BlueField-4 平台。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-bf4-deployment/SKILL.md) |
| `doca-caps` | 唯讀列舉 DOCA 裝置、PCIe 位址與各函式庫能力。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-caps/SKILL.md) |
| `doca-comch` | 建立主機與 BlueField 間的 PCIe 控制或大量資料訊息通道。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-comch/SKILL.md) |
| `doca-comm-channel-admin` | 唯讀列舉 Comch 裝置、伺服器與連線狀態。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-comm-channel-admin/SKILL.md) |
| `doca-common` | 處理 DOCA context、裝置、記憶體、buffer 與進度引擎生命週期。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-common/SKILL.md) |
| `doca-compress` | 透過 DOCA 卸載 DEFLATE 壓縮／解壓與 LZ4 解壓。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-compress/SKILL.md) |
| `doca-container-deployment` | 以 BlueField 靜態 Pod 部署及排查 DOCA 服務容器。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-container-deployment/SKILL.md) |
| `doca-debug` | 按安裝、版本、建置、連結與執行層次排查 DOCA 問題。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-debug/SKILL.md) |
| `doca-devemu` | 在 BlueField 模擬 PCIe、virtio-net 或 virtio-fs 裝置。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-devemu/SKILL.md) |
| `doca-dma` | 建立 DOCA DMA 記憶體複製工作、權限與完成處理。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-dma/SKILL.md) |
| `doca-dms` | 操作 DMS 管理服務、gNMI／gNOI、驗證及故障排查。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-dms/SKILL.md) |
| `doca-dpa` | 建立 DPA context、載入程式並從主機啟動 DPA kernels。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-dpa/SKILL.md) |
| `doca-dpdk-bridge` | 在既有 DPDK 資料平面中加入 DOCA 能力與硬體導流。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-dpdk-bridge/SKILL.md) |
| `doca-erasure-coding` | 卸載 Reed-Solomon 同位元計算、資料重建與更新。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-erasure-coding/SKILL.md) |
| `doca-eth` | 建立 Ethernet 收送佇列、管理 buffer 與排查封包處理。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-eth/SKILL.md) |
| `doca-firefly` | 部署及調整 Firefly PTP 時間同步服務。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-firefly/SKILL.md) |
| `doca-flow` | 用 C API 建立 DOCA Flow 封包匹配、動作與轉送管線。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-flow/SKILL.md) |
| `doca-flow-perf` | 量測 DOCA Flow 控制平面的規則插入效能。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-flow-perf/SKILL.md) |
| `doca-flow-tune` | 根據管線快照與計數器調整 DOCA Flow 效能。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-flow-tune/SKILL.md) |
| `doca-gpunetio` | 讓 CUDA kernels 直接操作 DOCA Ethernet 收送佇列。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-gpunetio/SKILL.md) |
| `doca-hardware-safety` | 針對 DPU／NIC 硬體變更建立目標、維護與還原確認流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-hardware-safety/SKILL.md) |
| `doca-mgmt` | 以 DOCA Management API 管理裝置、representor 與能力查詢。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-mgmt/SKILL.md) |
| `doca-pcc` | 載入與操作自訂可程式化壅塞控制演算法。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-pcc/SKILL.md) |
| `doca-pcc-counters` | 啟用及讀取 PCC 韌體／硬體診斷計數器。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-pcc-counters/SKILL.md) |
| `doca-pcc-ztr-rttcc-algo` | 部署、調整與評估 BlueField-3 的 ZTR RTT 壅塞控制。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-pcc-ztr-rttcc-algo/SKILL.md) |
| `doca-programming-guide` | 選擇 DOCA 範例並建立第一個程式的建置與執行流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-programming-guide/SKILL.md) |
| `doca-public-knowledge-map` | 定位 DOCA 官方文件、安裝路徑、範例與版本資訊。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-public-knowledge-map/SKILL.md) |
| `doca-rdma` | 使用 DOCA RDMA 處理 RoCE／InfiniBand 資料傳輸。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-rdma/SKILL.md) |
| `doca-rmax` | 在 BlueField 建立 Rivermax 精準時序媒體接收串流。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-rmax/SKILL.md) |
| `doca-setup` | 準備及檢查 DOCA 安裝、建置環境、hugepages 與裝置設定。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-setup/SKILL.md) |
| `doca-sha` | 在支援的 BlueField-2 硬體卸載 SHA 摘要運算。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-sha/SKILL.md) |
| `doca-sha-offload-engine` | 把 DOCA SHA Offload Engine 接入既有 OpenSSL 流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-sha-offload-engine/SKILL.md) |
| `doca-socket-relay` | 將 socket 應用程式透過 Socket Relay 橋接到 BlueField。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-socket-relay/SKILL.md) |
| `doca-spcx-cc` | 以 doca_spcx_cc 載入、設定及觀測 PCC 演算法。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-spcx-cc/SKILL.md) |
| `doca-sta` | 在 BlueField 建立 NVMe-over-Fabrics 儲存目標。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-sta/SKILL.md) |
| `doca-structured-tools-contract` | 定義呼叫既有 DOCA tools 的結構化執行契約。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-structured-tools-contract/SKILL.md) |
| `doca-telemetry` | 以各領域 Telemetry reader 讀取 DOCA 硬體計數事件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-telemetry/SKILL.md) |
| `doca-telemetry-exporter` | 設定 Telemetry schema、事件來源及匯出發布介面。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-telemetry-exporter/SKILL.md) |
| `doca-telemetry-utils` | 查詢診斷計數器 schema、Data ID 與裝置支援能力。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-telemetry-utils/SKILL.md) |
| `doca-upgrade` | 規劃並確認 DOCA 套件、BFB、容器版本升降版與還原。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-upgrade/SKILL.md) |
| `doca-urom` | 將 HPC／UCX／MPI 遠端記憶體操作卸載到 BlueField。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-urom/SKILL.md) |
| `doca-urom-svc` | 部署 BlueField UROM Service 並設定主機配對、佇列與 UCX。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-urom-svc/SKILL.md) |
| `doca-verbs` | 以 DOCA Core 直接控制 QP、CQ、PD、SRQ 等 verbs 物件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-verbs/SKILL.md) |
| `doca-version` | 檢查 DOCA 各元件版本一致性與功能可用版本。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/doca-version/SKILL.md) |

#### Dynamo（4）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `dynamo-interconnect-check` | 檢查 Dynamo 分離式推論部署的 NIXL／UCX／NCCL、RDMA 及 NVLink 傳輸。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/dynamo-interconnect-check/SKILL.md) |
| `dynamo-recipe-runner` | 選擇、驗證及調整 Dynamo Kubernetes recipe，部署指定模型、後端與 GPU 配置。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/dynamo-recipe-runner/SKILL.md) |
| `dynamo-router-starter` | 設定 Dynamo 路由模式並驗證 router 端點。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/dynamo-router-starter/SKILL.md) |
| `dynamo-troubleshoot` | 診斷 Dynamo 的 pod、模型快取、PVC、worker、router 與 benchmark 失敗。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/dynamo-troubleshoot/SKILL.md) |

#### Earth2Studio（7）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `earth2studio-create-datasource` | 為遠端資料來源建立並驗證 Earth2Studio 資料來源包裝類別。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/earth2studio-create-datasource/SKILL.md) |
| `earth2studio-create-diagnostic` | 建立 Earth2Studio 單步診斷模型，包括衍生量與生成式轉換。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/earth2studio-create-diagnostic/SKILL.md) |
| `earth2studio-create-prognostic` | 建立 Earth2Studio 逐時間步推進的預報模型包裝類別。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/earth2studio-create-prognostic/SKILL.md) |
| `earth2studio-data-fetch` | 透過既有 Earth2Studio 資料來源，取得指定變數及時間的天氣氣候資料。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/earth2studio-data-fetch/SKILL.md) |
| `earth2studio-deterministic-forecast` | 串接模型、資料來源與 IO，建立 Earth2Studio 確定性預報腳本。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/earth2studio-deterministic-forecast/SKILL.md) |
| `earth2studio-discover` | 依天氣或氣候需求尋找 Earth2Studio 模型、資料來源與範例。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/earth2studio-discover/SKILL.md) |
| `earth2studio-install` | 使用 uv 或 pip 安裝 Earth2Studio，選擇模型相依套件並設定環境。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/earth2studio-install/SKILL.md) |

#### Holoscan（15）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `holoscan-app-debug-build-run` | 診斷 Holoscan application 或獨立 Module 的建置、執行、停滯及輸出錯誤。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/holoscan-app-debug-build-run/SKILL.md) |
| `holoscan-install-conda` | 核對 Holoscan SDK 5.x Conda 套件供應情況，選擇可支援的安裝方式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/holoscan-install-conda/SKILL.md) |
| `holoscan-install-container` | 檢查版本與主機相容性後，安裝及驗證 Holoscan SDK 5.x CUDA 13 開發容器。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/holoscan-install-container/SKILL.md) |
| `holoscan-install-debian` | 在 Ubuntu 24.04 安裝 Holoscan SDK 5.x 完整或模組化 C++ Debian 套件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/holoscan-install-debian/SKILL.md) |
| `holoscan-install-source` | 從指定 source ref 建置與驗證 Holoscan SDK 5.x。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/holoscan-install-source/SKILL.md) |
| `holoscan-install-wheel` | 在隔離環境安裝 Holoscan SDK 5.x CUDA 13 Python wheels 及相容元件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/holoscan-install-wheel/SKILL.md) |
| `holoscan-module-lifecycle` | 以 Holoscan CLI 建立、測試及封裝外部 Module，並驗證應用端整合。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/holoscan-module-lifecycle/SKILL.md) |
| `holoscan-setup` | 評估主機、版本供應與 CUDA 13 相容性，選擇 Holoscan SDK 5.x 安裝方式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/holoscan-setup/SKILL.md) |
| `hsb-app` | 依硬體與版本尋找、執行及分析 Holoscan Sensor Bridge 範例應用。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/hsb-app/SKILL.md) |
| `hsb-flash` | 依板卡型號與版本，燒錄 Holoscan Sensor Bridge FPGA。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/hsb-flash/SKILL.md) |
| `hsb-ip-create-top` | 由已驗證的 HOLOLINK_def.svh 建立或解讀 HSB FPGA_top.sv wrapper。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/hsb-ip-create-top/SKILL.md) |
| `hsb-ip-def` | 產生、驗證、比較與解讀 HSB HOLOLINK_def.svh 巨集。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/hsb-ip-def/SKILL.md) |
| `hsb-ip-packetizer` | 選擇或解讀 HSB Sensor RX packetizer 的 HOLOLINK_def.svh 欄位。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/hsb-ip-packetizer/SKILL.md) |
| `hsb-setup` | 建立 Holoscan Sensor Bridge 開發環境、範例容器與硬體連線。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/hsb-setup/SKILL.md) |
| `hsb-test` | 依使用者測試計畫在 HSB 硬體執行適用項目，產生通過／失敗報告。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/hsb-test/SKILL.md) |

#### Isaac for Healthcare（14）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `i4h-lerobot-viz` | 在瀏覽器檢視已轉換 LeRobot 資料集的影片及狀態／動作時間軸。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-lerobot-viz/SKILL.md) |
| `i4h-workflow` | 說明 i4h workflow 執行架構，將需求導向對應階段。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow/SKILL.md) |
| `i4h-workflow-create` | 建立含基本 Scene、地面、燈光與 idle 模式的最小 Workflow。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-create/SKILL.md) |
| `i4h-workflow-dataset-annotate` | 使用相容 OpenAI API 的視覺模型，評分或篩選 workflow HDF5 episodes。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-dataset-annotate/SKILL.md) |
| `i4h-workflow-dataset-convert` | 將 workflow HDF5 錄製資料轉成可訓練及瀏覽的 LeRobot 資料集。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-dataset-convert/SKILL.md) |
| `i4h-workflow-dataset-mimic` | 透過動作擾動擴增 workflow HDF5 示範資料，支援限制指定節點片段。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-dataset-mimic/SKILL.md) |
| `i4h-workflow-dataset-replay` | 在原始 Scene 重播 workflow HDF5 episode，檢查軌跡與錄製結果。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-dataset-replay/SKILL.md) |
| `i4h-workflow-dataset-teleop` | 透過鍵盤、leader、VR 或 bus 遙操作，將示範錄製為 workflow HDF5。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-dataset-teleop/SKILL.md) |
| `i4h-workflow-e2e` | 執行從示範錄製、資料處理到策略 checkpoint 驗證的完整 workflow。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-e2e/SKILL.md) |
| `i4h-workflow-finetune` | 使用相容 LeRobot 資料，微調 manifest 定義的 GR00T 或 openpi remote Task。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-finetune/SKILL.md) |
| `i4h-workflow-scene-edit` | 修改既有 workflow 的場景、資產、相機、隨機化及任務成功規則。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-scene-edit/SKILL.md) |
| `i4h-workflow-setup` | 檢查並建立 workflow runtime，修復缺少環境或第三方元件問題。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-setup/SKILL.md) |
| `i4h-workflow-train-rl` | 使用 RSL-RL 或 RLinf 線上訓練、評估及匯出 Workflow 策略。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-train-rl/SKILL.md) |
| `i4h-workflow-validate` | 執行策略或規則控制器 rollout，驗證 workflow 模擬是否成功。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/i4h-workflow-validate/SKILL.md) |

#### Isaac Perception（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `foundationpose-pipeline` | 調整 BOP 資料集、執行 FoundationPose 與 TAO 深度流程，評估姿態結果。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/foundationpose-pipeline/SKILL.md) |
| `foundationpose-setup` | 安裝或修復 FoundationPose 流程，處理相依衝突並建置 FoundationStereo TensorRT engine。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/foundationpose-setup/SKILL.md) |

#### Isaac ROS（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `isaac-humanoid-cloud-control` | 在 Isaac Sim 執行 Unitree G1 雲端導航串流展示與受控吊架釋放。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/isaac-humanoid-cloud-control/SKILL.md) |

#### Jetson（36）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `jetson-build-source` | 從 bsp_sources 重建 kernel、裝置樹與外部模組。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-build-source/SKILL.md) |
| `jetson-customize-camera` | 為 Orin／Thor 自訂載板產生相機感測器裝置樹 overlay。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-customize-camera/SKILL.md) |
| `jetson-customize-clocks` | 在刷機前設定 CPU／GPU／EMC 時脈與 DVFS。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-customize-clocks/SKILL.md) |
| `jetson-customize-fan` | 調整 nvfancontrol 風扇曲線、profile 與開機預設。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-customize-fan/SKILL.md) |
| `jetson-customize-mgbe` | 以裝置樹 overlay 啟用 Thor MGBE QSFP 網路。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-customize-mgbe/SKILL.md) |
| `jetson-customize-nvpmodel` | 新增或調整 nvpmodel 功耗模式與頻率限制。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-customize-nvpmodel/SKILL.md) |
| `jetson-customize-pcie` | 設定各 PCIe controller 啟用、lanes 與連線速度。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-customize-pcie/SKILL.md) |
| `jetson-customize-pinmux` | 依 pinmux XLSM 設定腳位功能、方向與初始狀態。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-customize-pinmux/SKILL.md) |
| `jetson-customize-uphy` | 設定 Orin／Thor 自訂載板的 UPHY lane 分配。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-customize-uphy/SKILL.md) |
| `jetson-customize-usb` | 透過裝置樹 overlay 啟用或停用 USB2／USB3 埠。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-customize-usb/SKILL.md) |
| `jetson-derive-carrier` | 從參考 devkit 建立自訂載板檔案與裝置樹骨架。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-derive-carrier/SKILL.md) |
| `jetson-diagnostic` | 唯讀取得 Jetson 記憶體、GPU、溫度、電源與服務快照。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-diagnostic/SKILL.md) |
| `jetson-download-bsp` | 下載目標平台的 Jetson Linux BSP、rootfs 與工具鏈。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-download-bsp/SKILL.md) |
| `jetson-flash-image` | 將已準備好的 BSP 映像刷入 RCM 模式的 Jetson。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-flash-image/SKILL.md) |
| `jetson-generate-kb` | 根據 BSP 與原始碼建立目標平台知識文件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-generate-kb/SKILL.md) |
| `jetson-headless-mode` | 規劃及套用無螢幕模式，回收 GUI 與服務記憶體。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-headless-mode/SKILL.md) |
| `jetson-inference-mem-tune` | 為 LLM／VLM 選擇 Jetson 推論框架與記憶體參數。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-inference-mem-tune/SKILL.md) |
| `jetson-init-image` | 解開 BSP／rootfs、套用 binaries 並記錄映像位置。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-init-image/SKILL.md) |
| `jetson-init-source` | 建立 BSP 原始碼工作區、overlay 追蹤與交叉編譯工具鏈。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-init-source/SKILL.md) |
| `jetson-init-target` | 建立新 Jetson 平台 profile 並設定目前目標。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-init-target/SKILL.md) |
| `jetson-link-docs` | 把已下載的參考文件綁定到目前平台 profile。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-link-docs/SKILL.md) |
| `jetson-llm-benchmark` | 量測 Jetson LLM／VLM 服務效能並輸出結構化結果。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-llm-benchmark/SKILL.md) |
| `jetson-llm-serve` | 在 Jetson 建立 vLLM 或 SGLang 模型服務。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-llm-serve/SKILL.md) |
| `jetson-memory-audit` | 量測 DRAM／NvMap 使用量並驗證記憶體回收效果。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-memory-audit/SKILL.md) |
| `jetson-optimize-memory` | 調整 BSP 保留記憶體與未用子系統以回收 DRAM。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-optimize-memory/SKILL.md) |
| `jetson-package` | 依 JetPack、Orin／Thor 架構選擇容器與 Python 套件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-package/SKILL.md) |
| `jetson-print-bsp-info` | 列印主機端 BSP 版本、板卡設定與 rootfs 狀態。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-print-bsp-info/SKILL.md) |
| `jetson-print-device-info` | 列印執行中 Jetson 型號、系統與功耗模式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-print-device-info/SKILL.md) |
| `jetson-promote-image` | 把 overlay 檔案與建置產物移入待刷機 BSP 映像。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-promote-image/SKILL.md) |
| `jetson-quick-start` | 收集 Jetson／IGX BSP 需求並引導對應設定流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-quick-start/SKILL.md) |
| `jetson-set-target` | 切換至既有 Jetson 平台 profile。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-set-target/SKILL.md) |
| `jetson-speculative-decoding` | 在 Jetson vLLM 加入 EAGLE-3 或 draft model 推測解碼。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-speculative-decoding/SKILL.md) |
| `jetson-validate-image` | 刷機後執行 BSP 靜態檢查、裝置 smoke 與回歸驗證。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-validate-image/SKILL.md) |
| `jetson-video-benchmark` | 量測 Jetson 影片編解碼吞吐與設定差異。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-video-benchmark/SKILL.md) |
| `jetson-video-capability` | 依即時 API、官方範例與文件核對 Jetson codec 能力。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-video-capability/SKILL.md) |
| `jetson-video-recipe` | 把影片編碼需求轉成原生 SDK 與 PyNvVideoCodec 設定。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-video-recipe/SKILL.md) |

#### KAI Scheduler（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `runai-diagnose-failed-workload` | 診斷 Run:ai 工作的崩潰、OOM、映像下載、掛載與節點等失敗原因。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/runai-diagnose-failed-workload/SKILL.md) |
| `runai-get-workload-health-summary` | 彙整指定範圍或單一 Run:ai workload 的健康狀態。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/runai-get-workload-health-summary/SKILL.md) |

#### Learning（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nvidia-skill-finder` | 依 NVIDIA 產品、硬體與軟體需求，尋找適用的 NVIDIA skill。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvidia-skill-finder/SKILL.md) |

#### Maxine（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nvidia-broadcast` | 透過 MCP 操作 NVIDIA Broadcast 的效果、媒體、裝置與攝影機解析度。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvidia-broadcast/SKILL.md) |

#### Megatron-Core（5）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `mcore-create-issue` | 調查失敗的 GitHub Actions run 或 job，建立對應問題回報。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/mcore-create-issue/SKILL.md) |
| `mcore-linting-and-formatting` | 執行 Megatron-LM 的格式化、lint 及型別檢查，遵循專案風格。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/mcore-linting-and-formatting/SKILL.md) |
| `mcore-run-on-slurm` | 建立與監控 Megatron-LM Slurm 分散式訓練工作，診斷 rank 層級失敗。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/mcore-run-on-slurm/SKILL.md) |
| `mcore-split-pr` | 依 CODEOWNERS reviewer 群組拆分 Megatron-LM PR，降低單一 PR 的審查範圍。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/mcore-split-pr/SKILL.md) |
| `mcore-testing` | 建立或執行 Megatron-LM 單元與功能測試，核對 recipe、golden values 及 CI 行為。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/mcore-testing/SKILL.md) |

#### Mission Control（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `isaac-mission-control-showcase` | 執行 Isaac Sim、Nova Carter SIL 與 Mission Control 整合展示並驗證場景。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/isaac-mission-control-showcase/SKILL.md) |

#### MONAI（12）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `dicom-metadata-extract` | 擷取單一 DICOM 檔案指定中繼資料，標示標準欄位中可能存在的個資。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/dicom-metadata-extract/SKILL.md) |
| `dicom-series-preflight` | 在轉換或推論前，僅讀取標頭檢查單一 DICOM series。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/dicom-series-preflight/SKILL.md) |
| `dicom-series-to-volume` | 將單一 CT DICOM series 轉為 HU NIfTI 體積資料，並保留座標轉換依據。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/dicom-series-to-volume/SKILL.md) |
| `nv-generate-ct-rflow` | 使用 NV-Generate-CTMR rflow-ct 生成研究用合成 CT 體積與遮罩。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-generate-ct-rflow/SKILL.md) |
| `nv-generate-mr` | 使用 NV-Generate-CTMR rflow-mr 生成合成身體 MRI 體積。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-generate-mr/SKILL.md) |
| `nv-generate-mr-brain` | 使用 MR-Brain v1 生成 T1、T2、FLAIR、SWI 或 MRA 腦部 MRI。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-generate-mr-brain/SKILL.md) |
| `nv-generate-mr-brain-finetune` | 以 NIfTI datalist 微調 MR-Brain v1 的腦部 MRI 生成模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-generate-mr-brain-finetune/SKILL.md) |
| `nv-generate-vae-finetune` | 以 CT／MRI NIfTI datalist 微調 NV-Generate-CTMR MAISI VAE。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-generate-vae-finetune/SKILL.md) |
| `nv-reason-cxr` | 檢查 NV-Reason-CXR 胸部 X 光推論指令及基本執行功能，供工程研究使用。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-reason-cxr/SKILL.md) |
| `nv-segment-ct` | 使用 NV-Segment-CT VISTA3D 分割 CT NIfTI 體積並記錄 label-map 證據。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-segment-ct/SKILL.md) |
| `nv-segment-ct-finetune` | 微調 NV-Segment-CT VISTA3D，支援標準或固定通道 softmax 分割與 MLflow 紀錄。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-segment-ct-finetune/SKILL.md) |
| `nv-segment-ctmr` | 使用 NV-Segment-CTMR 分割 CT／MRI NIfTI 體積並記錄 label-map 證據。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-segment-ctmr/SKILL.md) |

#### NeMo（14）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `data-designer` | 規劃合成資料、建立資料集與資料生成管線。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/data-designer/SKILL.md) |
| `ethos-orchestrate` | 協調 ETHOS.md 的探索、建立與更新，選擇對應的工作流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/ethos-orchestrate/SKILL.md) |
| `nemo-fabric-build-adapter` | 依公開契約建立及維護 NeMo Fabric adapter，實作執行介面、schema 與封裝資訊。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-fabric-build-adapter/SKILL.md) |
| `nemo-fabric-integrate` | 透過 typed Python SDK，將 NeMo Fabric 整合進應用程式、服務或評估平台。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-fabric-integrate/SKILL.md) |
| `nemo-relay-debug-runtime-integration` | 診斷 NeMo Relay 載入失敗、scope 未生效、事件缺失及 plugin 連接問題。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-debug-runtime-integration/SKILL.md) |
| `nemo-relay-get-started` | 協助初次使用 NeMo Relay 者選擇快速入門流程並驗證首次整合。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-get-started/SKILL.md) |
| `nemo-relay-install` | 依語言、框架及 plugin 需求安裝 NeMo Relay，檢查 runtime 就緒狀態。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-install/SKILL.md) |
| `nemo-relay-instrument-calls` | 以 NeMo Relay scopes 包裝工具與模型呼叫，加入事件、middleware 與 guardrails。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-instrument-calls/SKILL.md) |
| `nemo-relay-instrument-context-isolation` | 隔離並行請求、非同步工作與 agent 的 Relay scope，正確傳遞父子關係。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-instrument-context-isolation/SKILL.md) |
| `nemo-relay-instrument-typed-wrappers` | 加入 NeMo Relay typed wrappers、領域型別或 provider codecs，保留 middleware 語意。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-instrument-typed-wrappers/SKILL.md) |
| `nemo-relay-migrate-from-flow` | 將程式、設定、文件與可觀測性介面從 NeMo Flow 遷移至 NeMo Relay。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-migrate-from-flow/SKILL.md) |
| `nemo-relay-plugin-adaptive-tuning` | 設定並評估 Relay adaptive plugin 的 telemetry、hints 與工具平行化行為。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-plugin-adaptive-tuning/SKILL.md) |
| `nemo-relay-plugin-build` | 建立或封裝可重用 Relay runtime 行為，驗證 plugin 並支援可回復註冊。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-plugin-build/SKILL.md) |
| `nemo-relay-plugin-observability` | 設定 Relay 事件、trajectory、OpenTelemetry／OpenInference 及自訂匯出。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-relay-plugin-observability/SKILL.md) |

#### NeMo Agent Toolkit（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `ethos-explore` | 探索 agent 程式與文件，整理用途、邊界與成功條件，供撰寫 ethos.md。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/ethos-explore/SKILL.md) |
| `ethos-write` | 依整理出的意圖建立或更新 agent 的 ethos.md，驗證格式與必要章節。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/ethos-write/SKILL.md) |

#### NeMo Framework（4）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nemo-automodel-distributed-training` | 選擇並設定 NeMo AutoModel 的 FSDP2、Megatron FSDP、DDP 與平行化策略。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-automodel-distributed-training/SKILL.md) |
| `nemo-automodel-launcher-config` | 設定 NeMo AutoModel 的互動式、Slurm 或 SkyPilot 工作啟動方式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-automodel-launcher-config/SKILL.md) |
| `nemo-automodel-model-onboarding` | 將新模型架構加入 NeMo AutoModel，完成實作、註冊及驗證。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-automodel-model-onboarding/SKILL.md) |
| `nemo-automodel-recipe-development` | 建立或修改 NeMo AutoModel 訓練與評估 recipe、YAML 與執行流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-automodel-recipe-development/SKILL.md) |

#### NeMo Megatron Bridge（20）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nemo-mbridge-mlm-bridge-training` | 使用模擬或真實資料執行 Megatron-LM 與 Megatron Bridge 訓練及關聯性驗證。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-mlm-bridge-training/SKILL.md) |
| `nemo-mbridge-multi-node-slurm` | 將單節點腳本改為多節點 Slurm 工作，處理容器、NCCL 與記憶體問題。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-multi-node-slurm/SKILL.md) |
| `nemo-mbridge-perf-activation-recompute` | 設定 Megatron Bridge activation recompute，以額外計算換取較低 GPU 記憶體用量。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-activation-recompute/SKILL.md) |
| `nemo-mbridge-perf-cpu-offloading` | 設定及驗證 Megatron Bridge 的 activation 與 optimizer state CPU offloading。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-cpu-offloading/SKILL.md) |
| `nemo-mbridge-perf-cuda-graphs` | 設定與驗證 Megatron Bridge 的完整迭代或 Transformer Engine 範圍 CUDA graphs。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-cuda-graphs/SKILL.md) |
| `nemo-mbridge-perf-expert-parallel-overlap` | 設定 Megatron Bridge MoE expert-parallel 通訊重疊、wgrad 排程與 flex dispatcher。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-expert-parallel-overlap/SKILL.md) |
| `nemo-mbridge-perf-hierarchical-context-parallel` | 啟用並驗證 Megatron Bridge 的階層式 context parallelism。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-hierarchical-context-parallel/SKILL.md) |
| `nemo-mbridge-perf-megatron-fsdp` | 啟用並驗證 Megatron Bridge 的 Megatron FSDP。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-megatron-fsdp/SKILL.md) |
| `nemo-mbridge-perf-memory-tuning` | 調整 Megatron Bridge 記憶體配置、平行化、recompute 與 offloading，降低峰值及 OOM。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-memory-tuning/SKILL.md) |
| `nemo-mbridge-perf-moe-comm-overlap` | 調整 Megatron Bridge MoE dispatch／combine 通訊重疊與 expert wgrad 排程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-moe-comm-overlap/SKILL.md) |
| `nemo-mbridge-perf-moe-dispatcher-selection` | 依硬體、expert parallelism 與最佳化階段，選擇 alltoall、DeepEP 或 HybridEP。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-moe-dispatcher-selection/SKILL.md) |
| `nemo-mbridge-perf-moe-hardware-configs` | 以硬體與模型家族的 MoE 組態範例為起點，重新驗證語意、拓樸及吞吐量。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-moe-hardware-configs/SKILL.md) |
| `nemo-mbridge-perf-moe-long-context` | 調整 Megatron Bridge 長上下文 MoE 訓練的 CP、recompute 與 dispatcher 配置。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-moe-long-context/SKILL.md) |
| `nemo-mbridge-perf-moe-optimization-workflow` | 依量測證據進行 Megatron Bridge MoE 瓶頸分析、平行化、A/B 調校與驗證。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-moe-optimization-workflow/SKILL.md) |
| `nemo-mbridge-perf-moe-vlm-training` | 規劃 Megatron Bridge MoE VLM 訓練，比較 FSDP 與多維平行化配置。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-moe-vlm-training/SKILL.md) |
| `nemo-mbridge-perf-parallelism-strategies` | 依模型大小與硬體拓樸，選擇及組合 Megatron Bridge 平行化策略。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-parallelism-strategies/SKILL.md) |
| `nemo-mbridge-perf-sequence-packing` | 設定 Megatron Bridge 的 LLM／VLM sequence packing 與長上下文訓練。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-sequence-packing/SKILL.md) |
| `nemo-mbridge-perf-tp-dp-comm-overlap` | 啟用與驗證 Megatron Bridge TP、DP 及 PP 通訊重疊。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-perf-tp-dp-comm-overlap/SKILL.md) |
| `nemo-mbridge-recipe-recommender` | 依模型、GPU、序列長度與訓練目標，選擇及客製 Megatron Bridge recipe。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-recipe-recommender/SKILL.md) |
| `nemo-mbridge-resiliency` | 設定 Megatron Bridge 容錯、慢節點偵測、程序內重啟與搶占復原。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-mbridge-resiliency/SKILL.md) |

#### NeMo Retriever（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nemo-retriever` | 使用 NeMo Retriever CLI 擷取、匯入、搜尋及查詢多模態文件集合。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-retriever/SKILL.md) |
| `nemo-retriever-mcp` | 透過 NeMo Retriever MCP 搜尋或新增文件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-retriever-mcp/SKILL.md) |

#### NeMo RL（5）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `launch-nemo-rl` | 使用 nrl-k8s 啟動、監控、停止及除錯 Kubernetes 上的 NeMo-RL recipes。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/launch-nemo-rl/SKILL.md) |
| `nemo-rl-auto-research` | 協調 NeMo-RL 假說、基準實驗、訓練、結果分析與可重現研究紀錄。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-rl-auto-research/SKILL.md) |
| `nemo-rl-brev-etiquette` | 在 Brev 執行 NeMo-RL 時，管理工作磁碟、大型檔案、快取與訓練產物。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-rl-brev-etiquette/SKILL.md) |
| `nemo-rl-docs` | 依 NeMo-RL 慣例更新文件索引與 docstrings。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-rl-docs/SKILL.md) |
| `nemo-rl-session-memory` | 保存及恢復 coding agent 的工作狀態，支援中斷、重啟與交接。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemo-rl-session-memory/SKILL.md) |

#### NemoClaw（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nemoclaw-user-guide` | 透過官方 Markdown 文件與 docs MCP，查詢 NemoClaw 安裝、操作及疑難排解。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemoclaw-user-guide/SKILL.md) |

#### Nemotron（4）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nemotron-customize` | 組合 Nemotron 資料整理、訓練、對齊、轉換、最佳化與評估流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemotron-customize/SKILL.md) |
| `nemotron-policy-generator` | 為 Nemotron 內容安全 guardrails 產生自訂政策、JSON taxonomy 與推論提示詞。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemotron-policy-generator/SKILL.md) |
| `nemotron-retrieval-recipes` | 規劃、調校、評估、匯出及部署 Nemotron embedding／reranking recipes。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemotron-retrieval-recipes/SKILL.md) |
| `nemotron-voice-agent-builder` | 使用 Pipecat 或 LiveKit 建立與調整即時 Nemotron 語音 agent。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemotron-voice-agent-builder/SKILL.md) |

#### Nemotron for Digital Health（5）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `ambient-healthcare-agent-with-nemotron-voice-agent` | 以 Nemotron Voice Agent 與 Pipecat 建立醫療預約、病患資料收集及工具呼叫流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/ambient-healthcare-agent-with-nemotron-voice-agent/SKILL.md) |
| `digital-health-clinical-asr-build` | 整理臨床術語與 IPA 標記，合成 Clinical ASR Flywheel 使用的 NeMo manifest。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/digital-health-clinical-asr-build/SKILL.md) |
| `digital-health-clinical-asr-eval` | 評分 Clinical ASR NeMo manifest，產生關鍵詞錯誤率及 IPA 來源診斷報表。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/digital-health-clinical-asr-eval/SKILL.md) |
| `digital-health-clinical-asr-finetune` | 依關鍵詞錯誤率啟動 Parakeet TDT v2 的 NeMo SFT 並離線重新評估。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/digital-health-clinical-asr-finetune/SKILL.md) |
| `digital-health-clinical-asr-setup` | 建立 Clinical ASR Flywheel 執行週期，檢查存取設定與 TTS／ASR 基本功能。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/digital-health-clinical-asr-setup/SKILL.md) |

#### Newton Physics Engine（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `ovnewton-usage`<br>YAML name: `using-ovnewton` | 透過 ovnewton 連接 Newton 與 Omniverse，匯入 stage、推進物理並同步狀態。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/ovnewton-usage/SKILL.md) |
| `physical-ai-physics-selection` | 比較及選擇機器人與 Physical AI 物理引擎，評估 Newton 與 ovnewton 整合。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/physical-ai-physics-selection/SKILL.md) |

#### NIM for Healthcare（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `medtech-model-evidence-export` | 將醫療 AI 推論的去敏中繼資料、參數、品質及重現證據匯出至 MLflow。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/medtech-model-evidence-export/SKILL.md) |
| `nv-reason-ct` | 對 3D 胸部或腹部 CT 執行 NV-Reason-CT 工程與研究推論。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nv-reason-ct/SKILL.md) |

#### NuRec（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `physical-ai-neural-reconstruction` | 導引 NuRec／NRE 的重建、USDZ 渲染、NCore 轉換與感測器模擬工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/physical-ai-neural-reconstruction/SKILL.md) |

#### NVFLare（9）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nvflare-autofl` | 以 agent 輔助 Auto-FL，最佳化既有 NVFLARE 模擬、POC 或正式工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvflare-autofl/SKILL.md) |
| `nvflare-autofl-report` | 為已停止的 NVFLARE Auto-FL 實驗產生可重現報告、JSON 摘要及進度圖。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvflare-autofl-report/SKILL.md) |
| `nvflare-convert-huggingface` | 將 Hugging Face Trainer／TRL SFTTrainer 訓練轉成 NVFLARE 聯邦學習工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvflare-convert-huggingface/SKILL.md) |
| `nvflare-convert-lightning` | 將 PyTorch Lightning 訓練轉成 NVFLARE 聯邦學習工作，保留各站資料在本地。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvflare-convert-lightning/SKILL.md) |
| `nvflare-convert-pytorch` | 以 Client API model exchange，將一般 PyTorch 訓練迴圈轉成 NVFLARE 工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvflare-convert-pytorch/SKILL.md) |
| `nvflare-diagnose-job` | 蒐集證據並診斷 NVFLARE 工作失敗、停滯、逾時或 client 中斷。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvflare-diagnose-job/SKILL.md) |
| `nvflare-fed-stats` | 透過 FedStatsRecipe 計算跨站表格及影像資料的聯邦統計。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvflare-fed-stats/SKILL.md) |
| `nvflare-orient` | 提供 NVFLARE 開放式需求導引，釐清架構及尚未確定框架的轉換任務。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvflare-orient/SKILL.md) |
| `nvflare-shared` | 提供其他 NVFLARE skills 指定使用的共用轉換參考、政策與模板。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvflare-shared/SKILL.md) |

#### NVSHMEM（9）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nvshmem-collect-performance-data` | 蒐集 NVSHMEM 頻寬、延遲與拓樸證據，封裝效能檢查資料。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvshmem-collect-performance-data/SKILL.md) |
| `nvshmem-configure-nic-pe-mapping` | 依拓樸建議 NVSHMEM NIC／HCA 與 PE 的對映及環境設定。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvshmem-configure-nic-pe-mapping/SKILL.md) |
| `nvshmem-docs` | 依版本查找 NVSHMEM／NVSHMEM4Py 的官方安裝、API 與執行文件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvshmem-docs/SKILL.md) |
| `nvshmem-enable-tma` | 調整或檢查 NVSHMEM CUDA kernel 的 TMA 共享記憶體註冊與直接傳輸。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvshmem-enable-tma/SKILL.md) |
| `nvshmem-get-started` | 說明 NVSHMEM 概念，建立、編譯及啟動第一個 C／C++ 或 Python 程式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvshmem-get-started/SKILL.md) |
| `nvshmem-install` | 規劃並驗證 NVSHMEM／NVSHMEM4Py 的套件、容器或原始碼安裝。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvshmem-install/SKILL.md) |
| `nvshmem-select-remote-transport` | 依系統與 kernel 證據，選擇及設定 NVSHMEM 跨節點遠端傳輸。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvshmem-select-remote-transport/SKILL.md) |
| `nvshmem-troubleshoot-and-report-bugs` | 診斷 NVSHMEM 啟動、崩潰、停滯、正確性與傳輸問題，準備 bug report。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvshmem-troubleshoot-and-report-bugs/SKILL.md) |
| `nvshmem-tune-performance` | 將 NVSHMEM 效能調校導向量測、傳輸選擇、NIC 對映或 TMA 工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nvshmem-tune-performance/SKILL.md) |

#### Omniverse（3）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `omniverse-cad-to-simready` | 協調 CAD／來源資產轉 USD、材質物理配置、SimReady 驗證及封裝。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/omniverse-cad-to-simready/SKILL.md) |
| `omniverse-realtime-viewer` | 導引 Omniverse Realtime Viewer USD 應用需求與專項參考文件。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/omniverse-realtime-viewer/SKILL.md) |
| `omniverse-usd-performance-tuning` | 診斷並最佳化 USD 載入時間、記憶體、FPS 與場景效能。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/omniverse-usd-performance-tuning/SKILL.md) |

#### Physical AI Dataset（4）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `cdf-simulation` | 將板卡 USD 與缺陷生成需求轉換成經驗證的 CDFJob 及 JobOrder。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/cdf-simulation/SKILL.md) |
| `physical-ai-defect-image-generation` | 在 OSMO 協調 Cosmos AnomalyGen 的 PCBA、金屬及玻璃缺陷資料生成。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/physical-ai-defect-image-generation/SKILL.md) |
| `physical-ai-infrastructure-setup-and-resilient-scaling` | 建立、擴展與修復 MicroK8s／Azure AKS 上的 Physical AI 合成資料基礎設施。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/physical-ai-infrastructure-setup-and-resilient-scaling/SKILL.md) |
| `physical-ai-video-data-augmentation` | 在 OSMO 選擇、執行及監控影片增強與自動標記流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/physical-ai-video-data-augmentation/SKILL.md) |

#### PhysicsNeMo（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `physicsnemo-discover` | 依科學機器學習需求，尋找 PhysicsNeMo 模型、datapipe 與既有範例。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/physicsnemo-discover/SKILL.md) |
| `physicsnemo-shard-tensor` | 以 ShardTensor 整合 domain parallelism，建立 shard patches 與多 GPU 正確性測試。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/physicsnemo-shard-tensor/SKILL.md) |

#### RAG（3）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `rag-blueprint` | 部署、設定、操作與修復 NVIDIA RAG Blueprint 的檢索、模型及相關服務。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/rag-blueprint/SKILL.md) |
| `rag-eval` | 依指定檔案結構執行 RAGAS 文件檢索回答品質評估。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/rag-eval/SKILL.md) |
| `rag-perf` | 對已部署的 NVIDIA RAG Blueprint 執行 profiling 與 aiperf 負載測試。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/rag-perf/SKILL.md) |

#### Riva（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `nemotron-asr-finetune` | 依領域或語言需求，協調 Nemotron Speech 的詞彙增強、語言模型與 ASR 微調。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemotron-asr-finetune/SKILL.md) |
| `nemotron-speech` | 部署與測試 Nemotron Speech 的 ASR、TTS 及 NMT NIM 服務。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/nemotron-speech/SKILL.md) |

#### RTX Remix（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `rtx-remix-modding` | 透過 MCP 操作 RTX Remix Toolkit 專案，替換遊戲材質及模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/rtx-remix-modding/SKILL.md) |

#### Settings（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `g-assist-mcp-skill` | 檢查或調整本機 NVIDIA 顯示、同步、色彩與 GPU 效能設定。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/g-assist-mcp-skill/SKILL.md) |

#### TAO Toolkit（82）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `paidf-cosmos-predict` | 準備並執行供 DEFT 媒體樣本使用的 Cosmos Predict 影片生成。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/paidf-cosmos-predict/SKILL.md) |
| `tao-analyze-changenet-rca` | 以影像證據分析 Visual ChangeNet 失敗原因與品質指標。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-analyze-changenet-rca/SKILL.md) |
| `tao-analyze-detection-kpi` | 比較偵測預測與真值，計算各類別 precision、recall 與 AP。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-analyze-detection-kpi/SKILL.md) |
| `tao-analyze-gaps-od-map` | 依偵測結果與真值找出 recall／precision／AP50 薄弱影像。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-analyze-gaps-od-map/SKILL.md) |
| `tao-analyze-gaps-visual-changenet` | 分析 VCN AOI 閾值、樣本弱點及待改善資料。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-analyze-gaps-visual-changenet/SKILL.md) |
| `tao-analyze-gaps-vlm-bcq` | 從 VLM 二元問答預測抽取假陽性與假陰性缺口。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-analyze-gaps-vlm-bcq/SKILL.md) |
| `tao-artifacts` | 定義及驗證 TAO 規格、工作紀錄、輸出與最佳結果契約。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-artifacts/SKILL.md) |
| `tao-convert-dataset-format` | 使用 tao-daft convert 轉換支援的 DAFT 資料格式。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-convert-dataset-format/SKILL.md) |
| `tao-data-io` | 為 TAO 工作暫存、掛載、下載與上傳資料及產物。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-data-io/SKILL.md) |
| `tao-finetune-anomalygennext` | 檢查 AnomalyGenNext 資料與設定並準備紋理微調。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-finetune-anomalygennext/SKILL.md) |
| `tao-finetune-clip` | 微調 CLIP，執行檢索、零樣本分類、embedding 與部署。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-finetune-clip/SKILL.md) |
| `tao-finetune-cosmos-embed` | 微調 Cosmos-Embed1 並執行影片文字檢索與去重。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-finetune-cosmos-embed/SKILL.md) |
| `tao-finetune-cosmos-reason` | 準備 Cosmos3 訓練輸入、後端、checkpoint 與初次更新驗證。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-finetune-cosmos-reason/SKILL.md) |
| `tao-finetune-huggingface-model` | 在 NGC PyTorch 容器微調沒有專用 TAO skill 的 HF 模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-finetune-huggingface-model/SKILL.md) |
| `tao-finetune-kumo-anomaly` | 微調 Kumo-Anomaly 並偵測多變量時間序列異常。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-finetune-kumo-anomaly/SKILL.md) |
| `tao-finetune-kumo-forecast` | 微調 Kumo-Forecast，執行多變量預測與 DARR 檢索。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-finetune-kumo-forecast/SKILL.md) |
| `tao-finetune-video-clip` | 微調 InternVideo2-CLIP，執行影片文字檢索與匯出部署。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-finetune-video-clip/SKILL.md) |
| `tao-generate-anomalies` | 執行 AnomalyGen 微調、合成異常影像與生成品質搜尋。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-generate-anomalies/SKILL.md) |
| `tao-generate-image-embeddings` | 用 CLIP、SigLIP 或 TAO checkpoint 產生影像 embeddings。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-generate-image-embeddings/SKILL.md) |
| `tao-generate-image-grounding` | 從影像與 caption 產生指涉文字及對應邊界框。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-generate-image-grounding/SKILL.md) |
| `tao-generate-od-defects` | 以 AnomalyGenNext 合成偵測缺陷並輸出驗證後 COCO 標籤。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-generate-od-defects/SKILL.md) |
| `tao-generate-referring-expressions` | 從影像與 KITTI 框產生區域描述、caption 與指涉標註。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-generate-referring-expressions/SKILL.md) |
| `tao-generate-video-reasoning-annotations` | 用 VLM／LLM 蒸餾影片描述、問答及推理訓練資料。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-generate-video-reasoning-annotations/SKILL.md) |
| `tao-launch-workflow` | 在 TAO 工作啟動前檢查平台與輸入並統一執行契約。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-launch-workflow/SKILL.md) |
| `tao-list-capabilities` | 從 packaged manifests 列出 TAO 模型、工作流與平台能力。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-list-capabilities/SKILL.md) |
| `tao-mine-aoi-images` | 為 AOI 改善流程嵌入弱點樣本並採掘相近來源影像。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-mine-aoi-images/SKILL.md) |
| `tao-mine-nearest-neighbors` | 從 embedding parquet 執行 TMM 最近鄰樣本採掘。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-mine-nearest-neighbors/SKILL.md) |
| `tao-mine-od-images` | 為物件偵測採掘與目標樣本相近、互不重複的來源影像。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-mine-od-images/SKILL.md) |
| `tao-port-huggingface-model` | 把 Hugging Face 視覺模型整合到 TAO 訓練與部署生態。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-port-huggingface-model/SKILL.md) |
| `tao-prepare-anomalygennext-inputs` | 整理偵測漏判、來源 mask 與乾淨影像的生成前輸入。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-prepare-anomalygennext-inputs/SKILL.md) |
| `tao-route-visual-changenet-samples` | 依增強模組資格分流 VCN 薄弱樣本。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-route-visual-changenet-samples/SKILL.md) |
| `tao-run-automl` | 執行 TAO 超參數搜尋、實驗追蹤與結果解讀。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-automl/SKILL.md) |
| `tao-run-automl-deft-pipeline` | 執行 AOI 基線 AutoML、DEFT 改善與最終 AutoML 精調。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-automl-deft-pipeline/SKILL.md) |
| `tao-run-deft-aoi` | 針對 ChangeNet PCB 檢測執行根因分析、合成、採掘與重訓。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-deft-aoi/SKILL.md) |
| `tao-run-deft-aoi-cosmos3` | 以 Cosmos3 執行 AOI 評估、缺口採掘、合成與改善迴圈。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-deft-aoi-cosmos3/SKILL.md) |
| `tao-run-deft-cr-its-mining` | 以資料採掘改善 ITS Cosmos-Reason 影片二元分類。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-deft-cr-its-mining/SKILL.md) |
| `tao-run-deft-object-detection` | 對 Grounding DINO 執行偵測缺口分析、採掘與反覆重訓。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-deft-object-detection/SKILL.md) |
| `tao-run-deft-od-aoi` | 以 RT-DETR 執行工業二元缺陷偵測資料改善迴圈。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-deft-od-aoi/SKILL.md) |
| `tao-run-deft-pas` | 依弱屬性與 caption 樣本改善 CLIP／SigLIP 圖文檢索。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-deft-pas/SKILL.md) |
| `tao-run-dinov3-ssl-deft` | 從未標註資料池反覆採掘並重訓 DINOv3 自監督模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-dinov3-ssl-deft/SKILL.md) |
| `tao-run-inference-service` | 啟動、呼叫及停止指定 TAO 網路的推論微服務。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-inference-service/SKILL.md) |
| `tao-run-on-brev` | 在既有 Brev GPU instance 透過容器執行 TAO 工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-on-brev/SKILL.md) |
| `tao-run-on-docker` | 透過本機或遠端 Docker 提交、追蹤及取消 TAO 工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-on-docker/SKILL.md) |
| `tao-run-on-kubernetes` | 以 Kubernetes GPU Jobs 執行單機或多節點 TAO 工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-on-kubernetes/SKILL.md) |
| `tao-run-on-slurm` | 以 SSH、SLURM 與 Pyxis／Enroot 執行遠端 TAO 工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-on-slurm/SKILL.md) |
| `tao-run-on-virtualenv` | 在既有 virtualenv 執行本機 Python 訓練／評估工作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-run-on-virtualenv/SKILL.md) |
| `tao-setup` | 建立 TAO session 的技能探索、認證檢查與主機前置流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-setup/SKILL.md) |
| `tao-setup-nvidia-gpu-host` | 檢查或準備 TAO GPU 主機的驅動、CUDA 與容器工具。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-setup-nvidia-gpu-host/SKILL.md) |
| `tao-token-efficient-execution` | 把重複 TAO 工作編成階段卡片並以小型獨立 session 執行。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-token-efficient-execution/SKILL.md) |
| `tao-train-action-recognition` | 訓練、評估與匯出 RGB／光流影片動作辨識模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-action-recognition/SKILL.md) |
| `tao-train-bevfusion` | 以 LiDAR 與相機融合訓練 BEVFusion 3D 偵測模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-bevfusion/SKILL.md) |
| `tao-train-centerpose` | 訓練 CenterPose 關鍵點與 6-DoF 物件姿態估計模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-centerpose/SKILL.md) |
| `tao-train-codetr` | 訓練及評估採混合指派監督的 Co-DETR 偵測模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-codetr/SKILL.md) |
| `tao-train-deformable-detr` | 訓練及部署 Deformable DETR 多尺度物件偵測模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-deformable-detr/SKILL.md) |
| `tao-train-depth-anything-v2` | 訓練與部署單眼相對或公制深度估計模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-depth-anything-v2/SKILL.md) |
| `tao-train-dino` | 訓練、蒸餾、量化及部署 DINO 物件偵測模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-dino/SKILL.md) |
| `tao-train-dinov3` | 以未標註影像持續預訓練 DINOv3 並匯出下游 backbone。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-dinov3/SKILL.md) |
| `tao-train-fast-foundation-stereo` | 訓練及部署低延遲 FastFoundationStereo 雙目深度模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-fast-foundation-stereo/SKILL.md) |
| `tao-train-foundation-stereo` | 訓練及部署 FoundationStereo 雙目視差與深度模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-foundation-stereo/SKILL.md) |
| `tao-train-grounding-dino` | 訓練與部署依文字提示偵測物件的 Grounding DINO。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-grounding-dino/SKILL.md) |
| `tao-train-image-classification` | 訓練、蒸餾、量化與部署 TAO 影像分類模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-image-classification/SKILL.md) |
| `tao-train-mask-auto-encoder` | 使用 MAE 遮罩重建進行視覺預訓練與微調。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-mask-auto-encoder/SKILL.md) |
| `tao-train-mask-auto-label` | 以少量點或框標註訓練 MAL 弱監督分割模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-mask-auto-label/SKILL.md) |
| `tao-train-mask-grounding-dino` | 訓練與部署依文字提示產生 instance masks 的模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-mask-grounding-dino/SKILL.md) |
| `tao-train-mask2former` | 訓練與部署 Mask2Former 全景、實例及語意分割。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-mask2former/SKILL.md) |
| `tao-train-metric-learning-recognition` | 訓練用於細粒度辨識、檢索與匹配的 metric embeddings。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-metric-learning-recognition/SKILL.md) |
| `tao-train-nvdinov2` | 以自蒸餾訓練 NVDINOv2 通用視覺表徵 backbone。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-nvdinov2/SKILL.md) |
| `tao-train-nvpanoptix3d` | 從帶姿態 RGB 影像訓練 3D 全景重建與占據補全。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-nvpanoptix3d/SKILL.md) |
| `tao-train-ocdnet` | 訓練、剪枝、量化及部署場景文字區域偵測模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-ocdnet/SKILL.md) |
| `tao-train-ocrnet` | 訓練及部署辨識裁切文字影像內容的 OCRNet。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-ocrnet/SKILL.md) |
| `tao-train-oneformer` | 訓練與部署以任務查詢統一多種分割的 OneFormer。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-oneformer/SKILL.md) |
| `tao-train-optical-inspection` | 用 Siamese 影像配對訓練製造缺陷與品質檢測。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-optical-inspection/SKILL.md) |
| `tao-train-pointpillars` | 從 LiDAR 點雲訓練與部署 PointPillars 3D 偵測。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-pointpillars/SKILL.md) |
| `tao-train-pose-classification` | 以 ST-GCN 分類骨架關鍵點序列的動作。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-pose-classification/SKILL.md) |
| `tao-train-reid` | 訓練用於跨相機人物匹配的 ReID embeddings。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-reid/SKILL.md) |
| `tao-train-rtdetr` | 訓練、蒸餾、量化與部署即時 RT-DETR 偵測模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-rtdetr/SKILL.md) |
| `tao-train-segformer` | 訓練及部署輕量 SegFormer 語意分割模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-segformer/SKILL.md) |
| `tao-train-single-step` | 執行一般 TAO 模型單次訓練、評估與匯出流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-single-step/SKILL.md) |
| `tao-train-sparse4d` | 準備多相機資料並訓練 Sparse4D 3D 偵測與追蹤。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-sparse4d/SKILL.md) |
| `tao-train-visual-changenet` | 訓練及部署以影像配對做 AOI 分類或變化分割的模型。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-train-visual-changenet/SKILL.md) |
| `tao-validate-dataset-format` | 用 tao-daft validate 檢查 DAFT 結構、schema 與交叉引用。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-validate-dataset-format/SKILL.md) |
| `tao-validate-recipe-transfer` | 將論文視覺訓練方法移植到自有資料並分析驗證失真。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/tao-validate-recipe-transfer/SKILL.md) |

#### Trustworthy AI（1）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `skill-card-generator` | 為指定既有 skill 產生或更新治理用 skill card。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/skill-card-generator/SKILL.md) |

#### Video Codec（2）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `jetson-video-pipeline` | 規劃並驗證 Jetson Video Codec SDK／PyNvVideoCodec 的編解碼、轉碼與 AV1 流程。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-video-pipeline/SKILL.md) |
| `jetson-video-setup` | 安裝、修復或檢查 Jetson Video Codec SDK／PyNvVideoCodec，執行官方編解碼基本測試。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/jetson-video-setup/SKILL.md) |

#### Video Search and Summarization (VSS)（4）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `rtvi-cv-customize-model` | 替換 VSS Alerts 的 DeepStream 偵測模型，設定匯出、解析器與 TensorRT engine。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/rtvi-cv-customize-model/SKILL.md) |
| `rtvi-cv-scaffold-vss-service` | 建立獨立 RTVI CV 微服務骨架，透過 Kafka mdx-raw 整合 VSS Search／Alerts。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/rtvi-cv-scaffold-vss-service/SKILL.md) |
| `rtvi-vlm-customize-model` | 替換 VSS Alerts 使用的 VLM，設定三個消費端並檢查服務健康。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/rtvi-vlm-customize-model/SKILL.md) |
| `vss-build-vision-ai` | 以 VSS Blueprint 組合、設定及部署影像描述、偵測、搜尋、警示與摘要能力。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/vss-build-vision-ai/SKILL.md) |

#### Warp（3）

| Identifier（若不同則加註 YAML name） | 用途摘要 | 原始來源 citation |
|---|---|---|
| `warp-compile-time-optimizer` | 降低 Warp kernel JIT 編譯與啟動時間，處理反覆重新編譯問題。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/warp-compile-time-optimizer/SKILL.md) |
| `warp-debug-gradients` | 診斷 Warp 可微分程式的錯誤梯度、NaN、訓練停滯與不正確收斂。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/warp-debug-gradients/SKILL.md) |
| `warp-eval` | 評估既有不規則、空間或模擬熱點是否適合改用 NVIDIA Warp 加速。 | [SKILL.md](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/skills/warp-eval/SKILL.md) |

</details>

<!-- SKILL_CATALOG_END -->
