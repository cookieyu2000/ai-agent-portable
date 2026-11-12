# Codync：手機協作、進度與排程

Codync 把這台電腦上的 coding agents 變成可從手機交辦工作的 bots，提供對話、
進度、需要批准／完成通知與 Routines 排程。Agent 和工作檔案仍在所選主機執行，
手機是操作介面；手機離線不會讓已啟動的主機工作停止。

本專案固定 **Codync v2.43.1**，來源 commit
`b1f2b53ca7e2c31b66c531338013a7ef7210491a`，於 2026-11-10 核對。
這是外部 runtime，不新增 Codex／Claude skill。
版本、資產 URL 和 SHA-256 以 [optional-sources.json](../manifests/optional-sources.json)
為準；上游授權為 Apache-2.0，見 [THIRD_PARTY.md](../THIRD_PARTY.md)。

## 安裝到每台工作主機

本專案安裝器只下載並驗證固定版本的 `codync-host`，放到 repository 外。
它不啟動 host、不安裝背景服務、不登入、不配對、不建立 bot 或排程，也不修改
Claude settings。預設 dry-run；只有 `--apply` 才會寫入安裝檔案。

Linux、WSL、macOS，在本 repository 根目錄執行：

```bash
./install-optional.sh --package codync --dry-run
./install-optional.sh --package codync --apply
```

預設 binary 位置：

```text
~/.local/share/ai-agent-portable/runtimes/codync/2.43.1/codync-host
```

使用 `--runtime-root /absolute/path` 可指定 runtime 根目錄，不能放進本 repository。
以安裝器印出的完整路徑為準。已有相同版本與內容可重跑；遇到內容不同時停止，
不覆寫既有檔案。

| 主機 | 本專案的固定 host 安裝 |
|---|---|
| Linux／WSL x86_64、arm64 | 支援官方 musl host archive |
| macOS Apple Silicon、Intel | 支援官方 host archive |
| 原生 Windows PowerShell／Git Bash | v2.43.1 沒有獨立 Windows host archive；不支援此 runtime 安裝 |

**Windows 請選一條路徑：**在 WSL 內依上面的 Linux 流程安裝，並讓 agent、專案、
host 都位於同一個 WSL 環境；或從
[官方 v2.43.1 release](https://github.com/leepokai/Codync/releases/tag/v2.43.1)
安裝 Windows desktop app，由它管理內附 host。Windows 的 Hallmark skill 可用
本專案 PowerShell 選配入口安裝；不能因此推定 `-Package All` 的 Codync runtime
也支援原生 Windows。上游 Windows host 隨桌面 app 發佈，見
[release workflow](https://github.com/leepokai/Codync/blob/v2.43.1/.github/workflows/host.yml)。

本專案只取 host binary，未安裝 archive 裡的 Linux screen／computer-use helpers；
這份流程涵蓋聊天、批准、進度與排程。需要遠端桌面畫面時另依上游 desktop app
流程設定，不能將本次安裝視為遠端桌面已可用。

## 先檢查，再手動啟用

先在將執行 host 的**同一個帳號與環境**安裝並登入所需 agent。Claude Code、
Codex 等 ACP adapters 另需 Node.js／`npx`；執行 bot 時可能從上游下載 adapter，
這些 adapter 不在本專案固定 binary 的範圍內。Linux 最小環境還需要系統
CA certificates。背景服務需 Linux systemd user session 或 macOS launchd。

先確認 **Node 的實際版本與路徑**，不能只檢查 `npx` 是否存在：

```bash
command -v node
node --version
command -v npx
npx --version
```

Node 12 不適用目前的 Claude／Codex ACP adapters。固定版 host 的 Node 偵測只看
`npx` 是否存在，可能將過舊的 Node 視為已安裝；`codync-host node` 也可能直接回報
已有 Node，而不升級它。建議依 [Node.js 官方下載](https://nodejs.org/en/download)
取得 Node 24，獨立安裝在使用者目錄，例如 `~/.local/share/nodejs/node-v24/`，
保留系統原有 Node。下列 `CODYNC_NODE_BIN` 請換成實際安裝的 `bin` 目錄；
目錄名稱本身不代表已安裝或版本正確。

```bash
CODYNC_NODE_BIN="$HOME/.local/share/nodejs/node-v24/bin"
"$CODYNC_NODE_BIN/node" --version
PATH="$CODYNC_NODE_BIN:$PATH" npx --version
```

主機安裝服務時須將這個 `bin` 放在 `PATH` 最前端；systemd／launchd 會記錄當下的
`PATH`，只在另一個 shell 切換 Node 不會更新既有服務。這不是本專案安裝器已代為
安裝的相依套件。來源：[Node 偵測與安裝](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/agent/node.rs)、
[服務環境](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/service/unix.rs)。

以下檢查不啟動 daemon，也不建立登入或配對資料：

```bash
CODYNC_BIN="$HOME/.local/share/ai-agent-portable/runtimes/codync/2.43.1/codync-host"
"$CODYNC_BIN" --version
"$CODYNC_BIN" --help
"$CODYNC_BIN" status
```

預期版本為 `codync-host 2.43.1`。尚未啟用時 `running: false` 是正常結果。
若 `status` 顯示已有服務或正在執行的 host，先確認原本的安裝方式與版本，
不要讓官方 desktop app 與此 standalone 安裝同時接管同一份資料／服務。

準備開始使用時，才在自己的 terminal 執行：

```bash
"$CODYNC_BIN" update --auto off
PATH="$CODYNC_NODE_BIN:$PATH" "$CODYNC_BIN" install
"$CODYNC_BIN" status
"$CODYNC_BIN" tui
```

上述流程假設已設定並核對 `CODYNC_NODE_BIN`；若原環境已有適用版本，也應先確認
服務將使用的 `node`／`npx`。**第一次啟動 host 就會建立 lead bot 及預設啟用的
Check in 排程，每天主機時區 09:00、18:00 執行**，不是等待手動新增 bot 才建立。
若使用已有資料的 `CODYNC_HOME`，啟動時也可能恢復先前未完成的工作與既有排程；
`serve`／`install` 都不能視為只開一個沒有工作的空服務。

`update --auto off` 會寫入 Codync 的私人設定，關閉一般自動更新；固定版本的
更新應先審查並更新本專案 manifest，再安裝到新的版本目錄。
不要對固定版本目錄執行上游 `update` 來就地換版。

**上游 `codync-host install` 與本專案 `install-optional.sh` 是不同動作。**
前者會建立 `~/.codync` 的資料庫與本機 token，寫入並啟動 systemd user unit
或 launchd agent，記錄當下的 binary 絕對路徑、`PATH` 與 `CODYNC_HOME`。
Unix 正式版還會包裝 `~/.claude/settings.json` 的 `statusLine`，讓額度送到 host；
原 status line 被保留並由 wrapper 呼叫。這些設定不屬於 portable repository。
來源：[CLI](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/main.rs)、
[Unix service](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/service/unix.rs)、
[updates](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/update/mod.rs)。

沒有 systemd 或只想暫時使用，可改在前景執行
`PATH="$CODYNC_NODE_BIN:$PATH" "$CODYNC_BIN" serve`，保留該 terminal，再開另一個
terminal 操作 `tui`／`pair`；前景 host 以 `Ctrl+C` 停止。不要同時執行前景 host
與背景服務。預設 Check in 必須在 host 起來後，透過 TUI／手機 UI 或官方本機 API
停用；不要直接修改 SQLite 或把私人 API token 寫入文件。停用方法見下節。
來源：[host 啟動](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/background.rs)、
[lead 初始化](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/chat/lead.rs)、
[工作恢復](https://github.com/leepokai/Codync/blob/v2.43.1/docs/architecture/conversation-runtime.md)。

## 建立工作 bot 與檢查預設行為

TUI 的 bot 清單按 `n` 建立 bot，選定名稱、agent 與專案；按 `e` 檢查設定。
例如分別建立 `Thinkarm Progress` 與 `Thinkarm Dev`，前者用於只讀進度摘要，
後者處理明確交辦的修改。專案路徑應是**執行 agent 那台主機**的絕對路徑，
例如 `"$HOME/thinkarm"` 展開後的絕對路徑；換設備時重新指定，UI 不一定會展開 `$HOME`。

首次使用先完成兩項設定：

1. 在 bot 的 **Permissions／Approvals** 檢查實際 agent 提供的模式。進度 bot
   優先選 `Read-only`；需要修改的 bot 可選 agent 支援的 `Manual` 或需批准模式。
   v2.43.1 新 bot 預設使用 agent 的 `Auto`／`Auto review`，並非每個命令都會送到
   手機等待批准。模式以目前 adapter 回報為準；工作目錄本身也不是 sandbox。
2. 首次啟動已自動建立 lead bot 與**啟用中的 Check in** routine，預設在**主機時區**
   的 09:00、18:00 執行。host 起來後，進該 bot 的 **Details → Routines**，檢查或
   暫停不需要的預設排程，再讓主機無人值守。TUI 選取 bot 後按 `R`，選取 routine
   按空白鍵切換啟用狀態，確認畫面已顯示停用；只停止 host 不等於停用該排程。

這些行為見固定版的
[new bot defaults](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/agent/new_bot.rs)、
[agent modes](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/agent/modes.rs)、
[lead bot](https://github.com/leepokai/Codync/blob/v2.43.1/docs/features/lead-bot.md)。
同一專案由多個 bots 編輯時仍可能衝突；Codync 不會自動替每個 bot 建 Git worktree。

## 手機配對與查看進度

2026-11-10 核對的 [iPhone 官方 App Store 版本](https://apps.apple.com/app/codync/id6760984418)
為 **2.42.1**，需要 **iOS 26.0 或更新版本**。依官方版本相容規則，它與本專案固定的
host **2.43.1** 相容，不需要 app／host 的版號完全相同。這是版本規則的核對，
不是已完成實際手機配對的宣告。來源：
[host 相容門檻](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/compat.rs)、
[iOS 相容門檻](https://github.com/leepokai/Codync/blob/v2.43.1/apps/ios/Kit/Sources/CodyncKit/Models/Compatibility.swift)。

1. 在 iPhone 安裝上述 app。若要離開家中／公司網路後透過官方 relay 連回主機，
   **先在 app 登入 Codync 帳號**。只用同一 Wi-Fi 或 Tailscale 可選
   **Continue without an account**，這條路徑不提供官方帳號 relay。
2. 手機初始設定選 **Linux**；帳號已經有其他電腦時，先選 **Pair a new computer**，
   再進入 Linux 的連線流程。使用 **Codync app 內的掃描器**。
3. 確認 host 正在執行後，在自己的主機 terminal 執行 `"$CODYNC_BIN" pair`，
   讓 app 掃描該 terminal 顯示的一次性 QR code。比對手機與 terminal 顯示的
   **六位確認碼**，確認是自己的裝置，再批准 terminal 的 **Let it in?**。
4. 要使用官方跨網路 relay，依提示批准 **Add this computer to …'s account?**。
   某些情況會合併為 **Add this computer to …'s account and let the phone in?**。
   確認提示的帳號正確；只批准手機而未將主機加入帳號，仍可能僅能經 Wi-Fi／Tailscale
   連線。帳號登入本身不代表已取得主機權限。配對碼／連結只留在自己的畫面，
   勿提交到 Git、文件或截圖。
5. 手機開啟同一個 bot，傳送工作、查看其目前狀態與 **Full conversation**，
   並允許系統通知，實際確認完成通知與批准通知能送達。通知功能需另外驗證，
   能看到聊天內容不等於背景推播已正常。需要出門使用時，另切到手機行動網路
   驗證連線，並保持主機與 host 在線。

以上為操作步驟，需由使用者在自己的手機與 terminal 完成；本專案安裝器沒有
完成手機配對或批准裝置。來源：
[iOS 初始設定](https://github.com/leepokai/Codync/blob/v2.43.1/apps/ios/Views/PairingView.swift)、
[主機配對批准](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/pair_cli.rs)。
Android 在 2026-11-10 的[官網入口](https://www.codync.dev/)仍連到封閉測試報名，
請依當時的官方入口取得，不將原始碼存在視為已正式上架。

終端機也能交辦給已建立的 bot：

```bash
"$CODYNC_BIN" send --bot "Thinkarm Progress" --wait --json \
  "只讀檢查 $HOME/thinkarm 的目前進度，列出已完成、進行中與阻礙。"
```

`--wait` 只等待本次回覆；超時不會停止 bot，也不會代替使用者批准操作。
不加 `--wait` 的成功只表示訊息已接受。不同名的 bot 用名稱即可；有重名時使用
bot ID。`status` 顯示 host 狀態，不是任務進度；任務進度以手機聊天或 `tui` 為準。
來源：[send CLI](https://github.com/leepokai/Codync/blob/v2.43.1/host/src/send_cli.rs)、
[remote relay](https://github.com/leepokai/Codync/blob/v2.43.1/docs/reference/remote-relay.md)。

## 工作日 09:00 的進度摘要

Routines 由 host 執行，手機不用保持 app 開啟。每個 routine 屬於一個 bot，
可在該 bot 的 **Details → Routines → +** 建立；TUI 選取 bot 按 `R`，再按 `n`。
先用 `Thinkarm Progress` 且將 agent 設為只讀模式，填入：

| 欄位 | 設定 |
|---|---|
| Name | `Thinkarm 工作日進度摘要` |
| When to run | `Schedule` |
| Repeat | `Weekdays` |
| Time | `09:00` |
| Time zone | `Asia/Taipei` |
| Custom cron（等效） | `0 9 * * 1-5` |
| TUI When（等效） | `weekdays 09:00 Asia/Taipei` |

Instruction 範例；將 `<專案絕對路徑>` 換成主機上 `"$HOME/thinkarm"` 展開後的路徑：

```text
只讀檢查 <專案絕對路徑> 的專案進度。
查看 git status --short、git log -5 --oneline，以及現有任務與測試紀錄。
用繁體中文回覆已完成、進行中、阻礙與下一步，區分紀錄證據與推測。
只報告本次實際讀到的內容；找不到資訊就明說。
不修改檔案、不安裝套件、不執行測試或訓練、不 commit/push，
不連接或控制機械手臂、不發送外部訊息。
把結果回覆在這個 bot 的聊天中。
```

儲存前確認畫面顯示的 **next run** 是台北時間的下一個工作日 09:00。
建立 routine 本身不等於執行驗證；**Test run** 會真的執行 instruction。
首次可手動執行一次這個只讀摘要，檢查回覆和手機推播，再保留排程啟用。
本專案安裝器不替你建立或試跑這個排程。

也可在 bot 聊天中交辦建立相同排程；Codync 內建 `routines` MCP tools，agent
可以建立／查詢／暫停 routine。要求它先列出既有同名項目，避免重複，並回報
實際儲存的名稱、cron、`Asia/Taipei`、啟用狀態與 next run。這是 bot 的能力，
不是 `codync-host schedule` shell command。

主機須持續開機且 host、agent 登入可用。關機、主動睡眠或闔上筆電可能中斷排程；
排程不會因手機在線就改到手機執行。忙碌 bot 會排隊處理，錯過的週期會合併，
不能保證每次剛好在 09:00 完成。遇到批准要求時依 bot／agent 權限處理。
暫停／刪除 routine 會取消待執行工作，但已在執行的工作可能繼續；需停止目前
工作時另使用 bot 的 Stop。詳見
[固定版 Routines 文件](https://github.com/leepokai/Codync/blob/v2.43.1/docs/features/routines.md)。

## 資料、停用與驗收

| 內容 | 位置／管理方式 |
|---|---|
| 固定 host binary／來源授權 | repository 外的 runtime 版本目錄 |
| Bot、對話、memory、routine、配對與本機 token | 預設 `~/.codync`；由 Codync 管理，勿放入本 repository |
| 程式與模型資料 | bot 設定的專案／工作目錄 |
| Agent 登入 | 各 agent 自己的本機設定與 credential store |

`CODYNC_HOME` 可變更私人資料目錄，但所有 host／CLI／service 必須一致。
不要把現有 `~/.codync` 的 identity、tokens 或整份資料同步到另一台主機；每台
主機各自安裝、登入、配對。手機到主機的 relay 內容採端到端加密，relay 仍可看見
帳戶、裝置與路由 metadata；模型供應商仍收到 agent 送出的 prompts。
公開 webhook 是另一條資料路徑，上游明載其內容不是端到端加密，本頁範例不用 webhook。

日常檢查與停用：

```bash
"$CODYNC_BIN" status
"$CODYNC_BIN" devices list
"$CODYNC_BIN" stop
```

`stop` 停止背景服務並保留設定／資料；前景 `serve` 用該 terminal 的 `Ctrl+C`。
移除背景服務時執行 `"$CODYNC_BIN" uninstall`，資料仍保留，上游會嘗試還原
Claude status line。手機遺失時用 `devices revoke <device-key>` 撤銷裝置；
`reset-token` 只換本機 helper token，不能當作撤銷手機權限的替代操作。

驗收請分開記錄：固定 archive 的 checksum、binary `--version`／`--help`、
host 啟動、實際手機配對、真實 agent 回覆、背景推播、routine 儲存與實際觸發。
只做 binary 檢查不能宣稱手機、推播或排程串接成功。不要把 `info --json`
輸出當成一般診斷附件，固定版會在其中輸出本機 API token。

上游操作與權限界線：[README](https://github.com/leepokai/Codync/blob/v2.43.1/README.md)、
[SECURITY.md](https://github.com/leepokai/Codync/blob/v2.43.1/SECURITY.md)、
[Linux servers](https://github.com/leepokai/Codync/blob/v2.43.1/docs/guides/linux-servers.md)。
