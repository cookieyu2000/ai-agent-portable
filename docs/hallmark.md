# Hallmark：預設網頁設計技能與獨立補裝

Hallmark 補充網頁的視覺方向、50 種主題與 `sloplint` 設計檢查，適合新網站、
產品頁、元件，以及明確指定的 UI 重設計。既有 `frontend-ui-engineering` 負責
元件、狀態與可存取性，`browser-testing-with-devtools` 負責瀏覽器行為、網路與
console 除錯；三者可以配合使用。

本專案採用 `Nutlope/hallmark` v2.0.0，固定來源 SHA：

```text
407fa689f4a276f2fd389208d271d0fef08f5058
```

版本、功能與最低相依以這份[固定版本 README][readme]、[SKILL.md][skill] 與
[執行流程][flow] 為準。

## 安裝

`install-codex.sh`、`install-claude.sh` 與 `install-all.sh` 的完整安裝已自動包含
Hallmark；Codex 與 Claude Code 各有 **445 個 portable skills**，即 NVIDIA 417
加上包含 Hallmark 的通用基線 28。`--without-nvidia` 也包含 Hallmark，安裝 28 個
通用 skills。這些入口都需要 Git、Bash 5、Python 3.10+ 與目標 agent CLI；
`PYTHON_COMMAND` 可指定 Python interpreter，例如 `PYTHON_COMMAND=python`。
Hallmark 來源仍由共用的 [optional-sources.json](../manifests/optional-sources.json)
管理，Codync 仍須另行選配安裝。

舊環境只需補 Hallmark 時，可保留既有 skills，從本 repository 根目錄先預覽，
再明確套用。獨立入口需要 Git、Python 3.10+ 與下載來源所需的網路。Bash：

```bash
./install-optional.sh --package hallmark --target codex
./install-optional.sh --package hallmark --target codex --apply
```

Windows PowerShell：

```powershell
.\install-optional.ps1 -Package Hallmark -Target Codex
.\install-optional.ps1 -Package Hallmark -Target Codex -Apply
```

要同時提供給 Codex 與 Claude Code，使用 `--target both`／`-Target Both`。
Windows Git Bash 的完整入口也會自動安裝 Hallmark；PowerShell 的
`install-nvidia.ps1` 只安裝 417 個 NVIDIA skills，須用上面的獨立入口補 Hallmark。
入口預設 dry-run；已用獨立入口安裝、內容相同的 Hallmark copy 可直接重跑完整安裝，
不會覆寫。同名內容不同、symlink／reparse point 或來源被修改時會停止，
先比較與備份，再決定如何遷移。

Hallmark 會複製到 `<CODEX_HOME>/skills/hallmark/` 或
`<CLAUDE_CONFIG_DIR>/skills/hallmark/`；預設為 `~/.codex`／`~/.claude`。
固定來源保存在 `~/src/ai-agent-sources/hallmark-<完整 SHA>/`，授權另存於各
agent profile 的 `licenses/hallmark/<完整 SHA>/`。安裝檔案不會啟動服務或瀏覽器。

安裝保留完整 `skills/hallmark/`，包含 `SKILL.md`、`LICENSE`、`agents/`、
`references/`、`scripts/`，以及主題圖片與素材索引。這個目錄沒有自己的
`package.json`；靜態工具使用 `.mjs` 與 Node 內建模組，不需要安裝上游網站。
瀏覽器相依另行準備。本專案不執行上游 `install.mjs` 或 `install-hook.mjs`，
也不註冊 Hallmark hooks；上游安裝器的覆寫行為不適用本專案的無覆寫規則。
來源：[skill 目錄][tree]、[上游安裝器][installer]。

上游 metadata 保持原樣：Codex 的 `allow_implicit_invocation` 是 `true`，因此
安裝後，agent 可能依 description 在新網站或新頁面任務選用 Hallmark；它不是
只能手動執行。需要確定使用哪套工作流時，明確指定技能與修改範圍。
來源：[Codex metadata][metadata]。

## 使用與既有 UI

重新開啟 agent，確認能找到 `hallmark` 後，在實際網站專案中使用。以下是傳給
Codex 的提示，不是 shell 命令；Claude Code 將 `$hallmark` 換成 `/hallmark`。

```text
$hallmark 為這個產品建立介紹頁，沿用專案的框架、品牌配色與真實截圖。
$hallmark 建立裝置狀態 dashboard，使用 app scope，保留目前的 API 契約。
$hallmark audit ./src/app
$hallmark redesign ./src/app
```

`audit` 只提出檢查結果；`redesign` 會修改設計。上游規定既有設計只有在使用者
明確點名 Hallmark 時才進入其重設計／稽核流程。一般 UI 修錯、小幅排版調整
繼續遵循專案原有設計；呼叫 `redesign` 時說明要保留的佈局、互動與品牌。
根目錄鎖定的 `design.md`／`DESIGN.md` 是上游 pre-flight 的第一優先訊號。
來源：[SKILL.md][skill]、[重設計流程][redesign]。

Dashboard、admin、settings 等工作畫面使用 `--scope app`，跳過行銷頁的 hero、
字數與照片配置規則，保留對比、focus、控制項與資料狀態檢查。提供真實數據、
照片與截圖；缺少素材時明確標記待補內容。來源：[App screens][flow]。

## Node 與真實瀏覽器檢查

先在執行 Hallmark 的同一個終端機檢查版本：

```bash
node --version
node -e 'if (Number(process.versions.node.split(".")[0]) < 18) { console.error("Hallmark scripts require Node.js 18+"); process.exit(1); }'
```

例如 Node 12 不符合需求；安裝技能檔案成功不代表 scripts 已可執行。
可使用已有的版本管理工具或獨立 Node 安裝，不需要為這套技能覆蓋系統 Node。

Hallmark 的靜態 scripts 最低需要 Node.js 18；`--render`、截圖工具另需
`puppeteer-core` 或 `puppeteer`，以及 Chrome／Chromium。Node 18 是 Hallmark
本身的最低要求，不能推論最新 Puppeteer 也支援它：查核時 Puppeteer 25.16.0
官方要求 Node 22.12+。依實際安裝版本的 engines 與瀏覽器支援範圍準備環境。
來源：[Hallmark 相依說明][flow]、[Puppeteer 系統需求](https://pptr.dev/guides/system-requirements)。

瀏覽器相依為選配，portable 安裝器不自動下載。可沿用網站專案已有的 Puppeteer；
需要新增時，在該網站專案依其套件管理規則安裝並鎖定相容的 `puppeteer-core`
版本。上游也支援全域安裝，README 提供的命令為：

```bash
npm install -g puppeteer-core
```

這個命令會安裝當時版本，並未由本專案固定；先確認 Node 與瀏覽器相容性。
已安裝在獨立目錄時，可用 `HALLMARK_PUPPETEER` 指向能解析該套件的目錄；
Chrome 不在常見位置時，以 `CHROME_PATH` 指定執行檔。

下列 Bash 範例需將 `HALLMARK_SKILL_DIR` 設為安裝器顯示的 Hallmark 目的地，
並切換到實際網站專案。`./src` 和 URL 依網站實際目錄、啟動方式與路由替換：

```bash
node "${HALLMARK_SKILL_DIR}/scripts/sloplint.mjs" --help
node "${HALLMARK_SKILL_DIR}/scripts/sloplint.mjs" ./src
node "${HALLMARK_SKILL_DIR}/scripts/sloplint.mjs" ./src --render --url http://localhost:3000/
```

第二個命令只做靜態檢查；第三個需要網站 dev server 已啟動，並會進入真實瀏覽器。
一般頁面的 render 使用 `320, 375, 414, 768, 1024, 1280, 1440, 1920` 八種寬度；
hero 階段使用較小的檢查集合。App 畫面在命令末尾加 `--scope app`。
來源：[sloplint CLI][sloplint]、[render 實作][render]。

缺少 Puppeteer、Chrome 或可用 dev server 時，報告「僅完成靜態檢查」及實際阻礙；
不可把靜態 pass 當成 render pass。畫面檢查也不等於 API、表單提交或實際裝置控制
已通過整合驗證。`.hallmark/` 紀錄、截圖、頁面輸出與素材留在網站工作目錄，
不放進本 portable repository。

## Together API 與素材授權

**基本設計、主題選擇與 lint 不需要 Together API key。** 固定版本的 pre-flight
在發現 `TOGETHER_API_KEY` 時會啟動 comp 步驟，以 Together 圖像 API 生成設計稿；
這是額外 API 使用，不包含在免費 skill 的概念裡。該版本沒有記載獨立的
`--no-comp` 開關；上游明確的略過條件是沒有這個環境變數。
來源：[comp 流程][comp]、[imagegen 實作][imagegen]。

若這次工作不用 Together 圖像生成，從未帶入該 key 的新 agent process 開始。
Bash 可只移除子程序的變數，原 shell 保持原樣：

```bash
env -u TOGETHER_API_KEY codex
```

Claude Code 將最後的 `codex` 改成 `claude`。PowerShell 可另開專用視窗，在該
視窗移除 process 環境變數後啟動 agent；這不刪除 Windows 持久化設定：

```powershell
Remove-Item Env:TOGETHER_API_KEY -ErrorAction SilentlyContinue
codex
```

本專案不保存或傳遞 API keys，也不為安裝驗證執行 `imagegen.mjs`。

Hallmark 程式與技能為 MIT，複製時保留其 `LICENSE`。圖庫素材各有授權，含 CC0、
public domain、CC BY、CC BY-SA；上游要求每張圖庫照片在頁面保留 credit。
使用、修改與發布素材時依該照片的來源及授權處理，MIT 不會取代照片授權。
真實產品畫面與提供的照片也應使用可公開的版本。來源：[MIT LICENSE][license]、
[素材與署名說明][imagery]。

[readme]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/README.md
[skill]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/SKILL.md
[flow]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/references/flow.md
[tree]: https://github.com/Nutlope/hallmark/tree/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark
[installer]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/scripts/install.mjs
[metadata]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/agents/openai.yaml
[redesign]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/references/redesign.md
[sloplint]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/scripts/sloplint.mjs
[render]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/scripts/sloplint-render.mjs
[comp]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/references/comp.md
[imagegen]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/scripts/imagegen.mjs
[license]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/LICENSE
[imagery]: https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/references/imagery.md
