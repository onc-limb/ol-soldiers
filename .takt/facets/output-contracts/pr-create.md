```markdown
# PR 作成結果（Facilitator）

## 完了状況

- status: `success` / `partial` / `blocked`
- 判定根拠: {1 行要約。なぜ success / partial / blocked と判断したか}

## PR

- url: {gh pr view で取得した PR URL}
- title: {作成した PR タイトル}
- branch: {push したブランチ名}
- base: {PR のベースブランチ}
- draft: true / false
- commit_sha: {push したコミットの短縮 SHA}

## 達成した Done 項目

- [x] {goal-review.md で「充足」と判定された項目を転記}

## 未達成 Done 項目（あれば PR 本文の「未解決」セクションへ転記済み）

| Done 項目 | 状況 | PR で確認したい事項 |
|-----------|------|---------------------|
| {項目 X} | 未充足 / 不明 | {ユーザー判断が必要な点} |

（全項目充足の場合は「なし」）

## assumptions（PR 本文の「仮定」セクションに記載）

- {仮定 1}
- {仮定 2}

（仮定がない場合は「なし」）

## open_questions（PR 本文の「ユーザー確認事項」セクションに記載。最大 5 項目）

1. {質問 1}
2. {質問 2}

（未解決事項がない場合は「なし」）

## blockers（PR 本文の「blocker」セクションに記載）

| 由来 | 種別 | 内容 | PR で確認したい事項 |
|------|------|------|---------------------|
| execute.md / goal-review.md | `blocked` / `failed` | {内容} | {ユーザーに最終確認したい点} |

（blocker がない場合は「なし」）

## テスト結果

- test_command: {goal-review.md から転記}
- tests_passed: true / false

## 変更ファイル一覧

- {execute.md の files_modified を統合した絶対パス}

## 実行した Bash コマンド（要約）

- {git status / git switch / git commit / git push / gh pr create のうち実行したもののみ列挙}
```
