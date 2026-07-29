# AI Agent Portable 協作規則

- 使用繁體中文說明；commands、paths 與 identifiers 保留英文。
- 此 repository 只保存可攜式 skills、來源 manifest、bootstrap scripts 與文件。
- 不得加入 credentials、tokens、cookies、sessions、history、plugin cache 或私人資料。
- Bootstrap 預設必須是 dry-run；只有明確傳入 `--apply` 才能修改使用者環境。
- 不覆寫既有 skill、plugin 或設定；遇到同名但內容不同的項目時停止並回報。
- 修改 scripts 後執行 `bash -n` 與 `./tests/run_all.sh`。
- 不自動 commit、push 或設定 remote。
