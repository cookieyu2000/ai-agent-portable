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

NVIDIA 固定版本為
[`b28d346437cf378402b19a730cd55cec516c77ff`](https://github.com/NVIDIA/skills/tree/b28d346437cf378402b19a730cd55cec516c77ff)，
包含 [nvidia-skills.txt](./manifests/nvidia-skills.txt) 的全部 **417 個 skills**。
授權依據為該版本的 [README](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/README.md#license)、
[LICENSE-APACHE](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/LICENSE-APACHE)
與 [LICENSE-CC-BY-4.0](https://github.com/NVIDIA/skills/blob/b28d346437cf378402b19a730cd55cec516c77ff/LICENSE-CC-BY-4.0)。

Bash 安裝使用完整 source checkout 的 symbolic links，根目錄授權與 skill 內的
通知隨來源保留。Windows PowerShell 複製完整 skill 目錄，並將兩份根目錄授權保存至
各 agent 的 `<config>/licenses/nvidia-skills/<SHA>/`，供複本一併查閱。
