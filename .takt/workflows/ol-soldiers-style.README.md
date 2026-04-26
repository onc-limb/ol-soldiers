# ol-soldiers-style

ol-soldiers で実現していた複数エージェントによる協調作業を、takt のカスタムワークフローとして再現した反復型フロー。特定プロジェクトに依存しない汎用構成。情報不足や blocker でユーザーへ質問せず、PR 作成まで自走して PR 本文に未確定事項を明記する設計。

## 起動方法

`.takt/workflows/` に配置すれば takt が自動認識する。workflow 選択メニューから `ol-soldiers-style` を選ぶか、`takt` に対してワークフロー指定オプションで指定する。

初回起動前の検証:

```bash
takt workflow doctor ol-soldiers-style
```

## 入力形式

2 通りを同一スキーマで受ける。Commander が intake step で自動判別する。

| ソース | 形式 |
|--------|------|
| GitHub issue | `https://github.com/<owner>/<repo>/issues/<n>`。`gh issue view` で本文・コメントを取得 |
| 直接入力 | URL 以外の文字列はそのまま扱う |

`gh` CLI は GitHub issue URL 入力時のみ必要。認証未了時など取得不能な場合は Commander が `open_questions` に状況を記録して先へ進める（停止しない）。

## フロー概要

```
intake (Commander)
  └─ 情報不足は assumptions / open_questions に記録 → plan_split
plan_split (Sergeant) → execute
execute (Sergeant as team_leader, Soldier x 最大 3 並列)
  └─ blocker は execute.md の blockers に記録 → task_review
task_review (Task Inspector)
  ├─ needs_revision / rejected → execute
  └─ all approved → completion_check
completion_check (Sergeant)
  ├─ 未完了 → execute
  └─ 全完了 → goal_review
goal_review (Goal Inspector)
  ├─ approved (目的達成 AND テスト通過) → pr_create
  ├─ needs_more_cycles → summarize_cycle → plan_split
  └─ blocked (未達成 Done / blocker を記録) → pr_create
loop_monitors: cycle[plan_split, goal_review] threshold 3 → pr_create
pr_create (Facilitator)
  └─ git commit/push + gh pr create → COMPLETE
```

- 並列上限: 3（`team_leader.max_parts`、takt 0.37 の engine 上限）
- サイクル上限: 3（`loop_monitors.threshold`）。到達時もユーザーへ質問せず PR で確定する
- サイクル間は Facilitator のサマリだけを引き継ぎ、生の思考ログは破棄（`session: refresh` + `pass_previous_response: false`）
- 情報不足・blocker・サイクル上限のいずれも、ワークフローを停止せず PR 本文に明記して `pr_create` で完結する

## エージェント対応表（ol-soldiers ↔ ol-soldiers-style）

| ol-soldiers | ol-soldiers-style | 責務 |
|-------------|-------------------|------|
| Commander | commander (persona) / intake step | 目的・Done 定義、不足情報の assumptions / open_questions 記録 |
| Sergeant | sergeant (persona) / plan_split + execute team_leader + completion_check | タスク分割、並列割当、完了確認、blocker の execute.md への記録 |
| Soldier | soldier (persona) / execute の part_persona | 単一タスク実装 |
| Inspector | task-inspector (persona) / task_review step | タスク単位の独立評価 |
| （新規） | goal-inspector (persona) / goal_review step | サイクル終端の目的 AND テスト判定、未達成 Done / blocker の記録 |
| （新規） | facilitator (persona) / summarize_cycle + pr_create + loop monitor | サイクル間要約、PR 作成（git commit/push + `gh pr create`） |

## 期待される出力

`.takt/runs/<run>/reports/` 配下に以下が生成される（takt 既定のレポートディレクトリ）。

- `intake.md` — 目的と Done 定義（統一スキーマ: source / title / body / acceptance_signals）+ assumptions / open_questions
- `plan-split.md` — タスクリスト（purpose / acceptance_criteria / related_files / dependencies / parallel_ok / context_digest）
- `execute.md` — 各 Soldier の status / summary / files_modified / issues + blockers + assumptions
- `task-review.md` — verdict 3 値（approved / needs_revision / rejected）+ findings（severity × category）
- `completion-check.md` — all_approved フラグと集計
- `goal-review.md` — verdict 3 値（approved / needs_more_cycles / blocked）+ tests_passed + test_command + 未達成 Done / blocker
- `cycle-summary.md` — サイクル番号 + 6 要素（目的 / 達成状況 / 決定事項 / 未解決課題 / 累積 assumptions・open_questions / 成果物ポインタ）
- `pr-create.md` — 完了状況（success / partial / blocked）+ PR URL + 達成 Done / 未達成 Done / assumptions / open_questions / blockers / テスト結果 / 変更ファイル

## PR 作成までの完結とユーザーレビュー

このワークフローはユーザー対話で停止しない。代わりに `pr_create` step で必ず PR を作成し、未確定事項は PR 本文に明記する。

完了状況は 3 区分:

1. `success`: `goal-review.md` が `approved` かつ open_questions / blockers 共に空。通常の ready PR を作成
2. `partial`: `approved` だが open_questions / assumptions が残る。`[partial] ` プレフィックス + draft PR
3. `blocked`: `goal-review.md` が `blocked`、または loop_monitors のサイクル上限到達。`[blocked] ` プレフィックス + draft PR

PR 本文には以下が必ず含まれる（レビュー時にユーザーが回答する設計）:

- 完了状況と判定根拠
- 達成 / 未達成 Done 項目
- assumptions（情報不足を補うために置いた仮定）
- open_questions（ユーザーにしか答えられない未解決事項。最大 5 項目）
- blockers（execute / goal-review で記録された停止要因）
- テスト結果（test_command + tests_passed）
- 変更ファイル一覧

ブランチが保護ブランチ（main / master）上の場合は `takt/{slug}` 形式で作業ブランチを切る（`{slug}` は intake の title から英小文字とハイフンで生成）。コミットメッセージは Conventional Commits 形式。

## 汎用性の担保

- テストコマンドはハードコードしない（Goal Inspector が `package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile` 等の規約から動的に特定）
- ol-soldiers の `inbox_write.sh` / `get_agent_id.sh` 等の通信スクリプトは持ち込まない（takt engine の責務と重複するため）
- 言語・フレームワーク固有の前提は persona / instruction / workflow のどこにも書かない
- PR 作成は `git` / `gh` CLI を Bash 経由で呼ぶ。ホスティング先は GitHub に限定（`gh pr create` の前提）
