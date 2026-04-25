```markdown
# 完了確認

## 全完了フラグ

- all_approved: true / false

## 集計

- approved_count: {件数}
- needs_revision_count: {件数}
- rejected_count: {件数}

## 残タスク（all_approved=false の場合のみ）

| task_id | verdict | 対応方針 |
|---------|---------|----------|
| T1 | `needs_revision` / `rejected` | {次の execute で再割当する方針} |
```
