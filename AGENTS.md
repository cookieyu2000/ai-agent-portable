# AI Agent Portable 協作規則

- 使用繁體中文說明；commands、paths 與 identifiers 保留英文。
- 此 repository 只保存可攜式 skills、來源 manifest、bootstrap scripts 與文件。
- 不得加入 credentials、tokens、cookies、sessions、history、plugin cache 或私人資料。
- Bootstrap 預設必須是 dry-run；只有明確傳入 `--apply` 才能修改使用者環境。
- 不覆寫既有 skill、plugin 或設定；遇到同名但內容不同的項目時停止並回報。
- 修改 scripts 後執行 `bash -n` 與 `./tests/run_all.sh`。
- 不自動 commit、push 或設定 remote。
- 選擇 skill 時，若 NVIDIA skill 的適用範圍涵蓋目前任務，同名或功能雷同的 skill 優先使用 NVIDIA 版本；通用工程 skill 僅補充未涵蓋的部分，不將產品限定 skill 套用到範圍外的任務。
