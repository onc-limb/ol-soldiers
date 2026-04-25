```markdown
# Intake: 目的定義

## 統一入力スキーマ

| フィールド | 値 |
|-----------|-----|
| source | `github_issue` / `direct_input` のどちらか |
| title | 1 行タイトル |
| body | 本文 |
| acceptance_signals | 入力から拾った達成条件の候補 |

## 目的

- purpose: {目的の一文要約}

## Done の定義（検証可能な最小単位のチェックリスト）

- [ ] done_criteria: {Done 項目 1}
- [ ] done_criteria: {Done 項目 2}

## 受け入れ条件（acceptance_signals）

- {入力から拾った達成条件の候補 1}
- {入力から拾った達成条件の候補 2}

## 判定

- verdict: `ready` / `info_gap`

## 情報不足時の質問（`verdict: info_gap` の場合のみ 1〜3 項目）

- {質問 1}
- {質問 2}
- {質問 3}
```
