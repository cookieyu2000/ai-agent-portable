# 選配技能與執行工具

這批選配整合補充程式碼關係圖、HTML 影片製作與跨 agent 長期記憶。原有 **444 個
portable skills** 的預設安裝清單維持不變；要使用本頁項目，另外執行
`install-optional.sh` 或 `install-optional.ps1`。所有入口預設 dry-run，只有明確
傳入 `--apply`／`-Apply` 才會取得來源、複製 skills 或安裝選配 runtime。

本專案保存固定來源 manifest 與安裝器，不保存上游完整 repositories、記憶內容、
sessions、history、cookies 或登入資料。固定版本與選定技能由
[optional-sources.json](../manifests/optional-sources.json) 管理。

## 納入的項目

| 套件 | 技能與補充用途 | 適合的工作 |
|---|---|---|
| Graphify | `graphify`：從程式碼與文件建立可查詢的關係圖。 | 熟悉大型專案、追蹤相依關係、理解修改影響。 |
| HyperFrames | `hyperframes`、`hyperframes-cli`、`hyperframes-registry`、`media-use`：以 HTML 編排、預覽與輸出影片。 | 產品介紹、社群影片、動態圖表與說明影片。 |
| ai-memory | 7 個長期記憶技能：檢索、交接、維護、訊息與路由。 | 跨 session、agent 或設備保留專案知識；需要另外準備記憶服務。 |

技能檔案與 runtime 分開安裝。只裝技能時，會得到操作指引與必要 references；
Graphify CLI、HyperFrames CLI 與 ai-memory binary 並不因此已可執行。
`--with-runtime`／`-WithRuntime` 才會把選定的執行工具裝到 repository 外的專用位置。

## 每台設備的安裝流程

先依 [README 的平台準備工作](../README.md#prerequisites) 取得本專案與 Git。
此選配入口需要 Python 3；Bash 入口與 PowerShell 入口使用同一份 manifest 與安裝邏輯。
所有命令都從 repository 根目錄執行。

### Windows PowerShell

先預覽要安裝到 Codex 的全部選配技能，再明確套用：

```powershell
.\install-optional.ps1 -Package All -Target Codex
.\install-optional.ps1 -Package All -Target Codex -Apply
```

連同選配 runtime 一起預覽／安裝：

```powershell
.\install-optional.ps1 -Package All -Target Codex -WithRuntime
.\install-optional.ps1 -Package All -Target Codex -WithRuntime -Apply
```

要選一個套件，將 `All` 改為 `Graphify`、`Hyperframes` 或 `Ai-memory`。
要同時裝到兩個 agent，使用 `-Target Both`。

### Linux、WSL、macOS 與 Windows Git Bash

```bash
./install-optional.sh --package all --target codex --dry-run
./install-optional.sh --package all --target codex --apply
```

連同選配 runtime：

```bash
./install-optional.sh --package all --target codex --with-runtime --dry-run
./install-optional.sh --package all --target codex --with-runtime --apply
```

單一套件範例：

```bash
./install-optional.sh --package graphify --target codex --with-runtime --dry-run
./install-optional.sh --package graphify --target codex --with-runtime --apply
```

選配安裝使用完整檔案複本，不依賴 symbolic links。同名目的地的內容不同時停止；
不覆寫既有 skill、runtime 或設定。已經是相同固定版本與內容時可重跑。

## Runtime 需求與啟用方式

### Graphify

Graphify 的 Python package 名稱是 `graphifyy`，CLI 名稱是 `graphify`，需要
Python 3.10+。本專案保留其 Codex 指引及獨立 references，安裝技能不呼叫
`graphify install`，因此不會更動其他專案的 `AGENTS.md` 或註冊 hooks。
來源：[固定版本 README](https://github.com/Graphify-Labs/graphify/blob/dac063456bc1f5d92354ec3936fd9dd1513a83f3/README.md)、
[Codex skill](https://github.com/Graphify-Labs/graphify/blob/dac063456bc1f5d92354ec3936fd9dd1513a83f3/graphify/skill-codex.md)、
[官方安裝器](https://github.com/Graphify-Labs/graphify/blob/dac063456bc1f5d92354ec3936fd9dd1513a83f3/graphify/install.py)。

完成安裝後重新啟動 agent，先用 `graphify` skill 查閱指引，再在需要分析的專案
產生圖譜。圖譜與輸出應留在該工作專案或其他外部資料目錄，不放進本 portable repository。

### HyperFrames

實際製作影片需要 Node.js 22+、FFmpeg，並可能依渲染流程下載瀏覽器及依賴。
這四個核心 skills 提供影片編排、CLI、registry 與媒體使用指引；額外的上游專題
skills 不在本次清單內。來源：[官方 README](https://github.com/heygen-com/hyperframes#skills)。

啟動 CLI 建立專案前，切換到本 portable repository 外的工作目錄；影片原始檔、
下載素材、`node_modules` 與輸出影片由各工作專案管理。

### ai-memory

本次採用 `akitaonrails/ai-memory`，固定為 `v3.2.8`；技能安裝與記憶服務啟用分開。
`--with-runtime` 只下載、驗證並解開對應平台的 binary。**安裝器不啟動 server，
不執行 `setup`／`run`，不註冊 hooks、MCP 或背景服務，也不擷取對話。**
來源：[固定版本安裝說明](https://github.com/akitaonrails/ai-memory/blob/0e5488073d7073caa3181bbaf184102b215dcf66/docs/install.md)。

需要長期記憶時，先閱讀固定版本的
[支援矩陣](https://github.com/akitaonrails/ai-memory/blob/0e5488073d7073caa3181bbaf184102b215dcf66/docs/support-matrix.md)
與[Windows 說明](https://github.com/akitaonrails/ai-memory/blob/0e5488073d7073caa3181bbaf184102b215dcf66/docs/windows.md)，
再自行決定 server 與 agent 的連接方式。原生 Windows 為 Experimental；WSL2
為 Supported。二者使用各自環境的安裝與資料目錄。

記憶的 Markdown、索引、資料庫、spool、個人設定與 tokens 必須放在 repository
外的私人資料目錄，並由你決定備份或同步方式。安裝這些技能不會搬移既有 session
或自動把設備之間的記憶同步。若只需要手動保存當前工作狀態，先使用既有 NVIDIA
`nemo-rl-session-memory`；自動檢索與跨 agent 記憶才使用這套 runtime。

## NVIDIA 優先與重複功能的處理

選配技能補充原清單沒有涵蓋的產品能力。NVIDIA 的產品、任務與先決條件涵蓋目前
工作時，仍優先使用 NVIDIA；不把 NVIDIA 的影片分析技能套用為 HTML 影片製作，
也不把特定產品的 session checkpoint 當成一般長期記憶服務。

Ponytail 的「先找既有程式、標準函式庫與平台功能，再寫最少必要程式」原則融入
既有 `karpathy-guidelines`，不另加一份重疊技能或 Ponytail hooks。參考：
[Ponytail 官方來源](https://github.com/DietrichGebert/ponytail)。

OpenCode 與 Orca 是另類 agent／多 agent 工作環境，這次沒有當成 Codex skill
加入；也不另裝第二套 `tigerless-labs/agent-memory`。這些選擇不影響既有的
NVIDIA 417 項與通用 27 項基線。

## 固定版本、授權與更新

逐項技能、來源 SHA、runtime 版本及下載 checksum 以
[optional-sources.json](../manifests/optional-sources.json) 為準。
選配來源 checkout 與授權保存在 repository 外；技能複本附帶對應來源的授權通知。
授權來源與範圍見 [THIRD_PARTY.md](../THIRD_PARTY.md)。

更新時先查閱上游差異，再修改固定 manifest；不要在既有來源目錄執行 `git pull`
或以新版本覆蓋已安裝檔案。若現有內容不相同，先比較、備份並自行遷移，再重跑安裝。
每台設備重新開啟 Codex 後，以 `/skills` 確認實際載入的選配項目。
