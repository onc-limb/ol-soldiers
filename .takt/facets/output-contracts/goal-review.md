```markdown
# 目的評価（Goal Inspector）

## verdict

- verdict: `approved` / `needs_more_cycles` / `blocked`

## テスト実行結果

- tests_passed: true / false
- test_command: {動的特定して実行したコマンド}
- 実行ログ（要約）: {成功/失敗の件数と代表的な失敗内容}

## Done 項目の充足状況（acceptance_status）

| Done 項目 | 状況 |
|-----------|------|
| {項目 1} | 充足 / 未充足 / 不明 |
| {項目 2} | 充足 / 未充足 / 不明 |

## AND 判定（目的達成 かつ テスト通過）

- 目的達成: 充足 / 未充足
- テスト通過: pass / fail
- 最終判定: `approved` は両方成立時のみ

## summary（判定根拠）

- {どの Done 項目が残っているか、テスト結果、なぜ approved / needs_more_cycles / blocked と判断したか}
```
