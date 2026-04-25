```markdown
# タスク評価（Task Inspector）

## 集計

- approved: {件数}
- needs_revision: {件数}
- rejected: {件数}

## 各タスクの verdict

| task_id | verdict | 根拠 |
|---------|---------|------|
| T1 | `approved` / `needs_revision` / `rejected` | {受け入れ条件との突き合わせ結果} |

## findings（発見事項）

| task_id | severity (重要度) | category | description | suggestion |
|---------|-------------------|----------|-------------|------------|
| T1 | `critical` / `major` / `minor` / `info` | `design` / `architecture` / `coding` / `performance` / `security` | {何が問題か} | {どう直せばよいか} |
```
