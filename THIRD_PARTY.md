# 第三方來源

此 repository 保存來源 manifest 與兩個 bundled skills；完整上游 repositories
於使用者明確 apply 時取得，不 vendor 至本專案。

| 來源 | 授權與保存方式 |
|---|---|
| `addyosmani/agent-skills` | MIT；版本固定於 [sources.tsv](./manifests/sources.tsv) |
| `ayghri/i-have-adhd` | MIT；版本固定於 [sources.tsv](./manifests/sources.tsv) |
| `karpathy-guidelines` | MIT；保存於 `skills/karpathy-guidelines/` |
| `backend-api-contracts` | 本專案 bundled skill，保存於 `skills/backend-api-contracts/` |
| OpenAI curated plugins | 由 marketplace 重新安裝，plugin cache 不保存於本專案 |
| `NVIDIA/skills` | 文件／skills：CC-BY-4.0；source code：Apache-2.0；保留各 skill 或檔案的個別授權通知 |
| `Nutlope/hallmark`（選配） | MIT；固定來源與完整 skill 目錄，複本附帶根 LICENSE；圖片仍依個別 CC／Public Domain 通知使用 |
| `leepokai/Codync`（選配） | Apache-2.0；固定 release archive SHA256，host binary 附帶固定來源 LICENSE 與來源記錄 |

選配版本由 [optional-sources.json](./manifests/optional-sources.json) 管理：
Hallmark 2.0.0 固定於 [`407fa689f4a276f2fd389208d271d0fef08f5058`](https://github.com/Nutlope/hallmark/tree/407fa689f4a276f2fd389208d271d0fef08f5058)，
Codync 2.43.1 固定於 [`b1f2b53ca7e2c31b66c531338013a7ef7210491a`](https://github.com/leepokai/Codync/tree/b1f2b53ca7e2c31b66c531338013a7ef7210491a)。
各自授權見 [Hallmark LICENSE](https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/LICENSE)、
[Codync LICENSE](https://github.com/leepokai/Codync/blob/b1f2b53ca7e2c31b66c531338013a7ef7210491a/LICENSE)。
Codync 本次僅安裝 host binary，不包含 archive 中的螢幕控制 helpers；手機對話、進度與排程
由 host 提供。Hallmark 圖庫的個別授權與署名要求見
[imagery reference](https://github.com/Nutlope/hallmark/blob/407fa689f4a276f2fd389208d271d0fef08f5058/skills/hallmark/references/imagery.md)。

NVIDIA 固定版本為
[`b28d346437cf378402b19a730cd55cec516c77ff`](https://github.com/NVIDIA/skills/tree/b28d346437cf378402b19a730cd55cec516c77ff)，
包含 [nvidia-skills.txt](./manifests/nvidia-skills.txt) 的全部 **417 個 skills**。
授權依據為該版本的 [README](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/README.md#license)、
[LICENSE-APACHE](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/LICENSE-APACHE)
與 [LICENSE-CC-BY-4.0](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/LICENSE-CC-BY-4.0)。

Bash 安裝使用完整 source checkout 的 symbolic links，根目錄授權與 skill 內的
通知隨來源保留。Windows PowerShell 複製完整 skill 目錄，並將兩份根目錄授權保存至
各 agent 的 `<config>/licenses/nvidia-skills/<SHA>/`，供複本一併查閱。
