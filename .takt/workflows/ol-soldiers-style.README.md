# ol-soldiers-style

ol-soldiers で実現していた複数エージェントによる協調作業を、takt のカスタムワークフローとして再現した反復型フロー。特定プロジェクトに依存しない汎用構成。

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

`gh` CLI は GitHub issue URL 入力時のみ必要。認証未了時は Commander が escalate_info_gap へルーティングする。

## フロー概要

```
intake (Commander)
  ├─ 情報不足 → escalate_info_gap
  └─ 目的確定 → plan_split
plan_split (Sergeant) → execute
execute (Sergeant as team_leader, Soldier x 最大 3 並列)
  ├─ 判断詰まり → escalate_blocked
  └─ 実装完了 → task_review
task_review (Task Inspector)
  ├─ needs_revision / rejected → execute
  └─ all approved → completion_check
completion_check (Sergeant)
  ├─ 未完了 → execute
  └─ 全完了 → goal_review
goal_review (Goal Inspector)
  ├─ approved (目的達成 AND テスト通過) → COMPLETE
  ├─ needs_more_cycles → summarize_cycle → plan_split
  └─ blocked → escalate_blocked
loop_monitors: cycle[plan_split, goal_review] threshold 3 → escalate_cycle_limit
```

- 並列上限: 3（`team_leader.max_parts`、takt 0.37 の engine 上限）
- サイクル上限: 3（`loop_monitors.threshold`）
- サイクル間は Facilitator のサマリだけを引き継ぎ、生の思考ログは破棄（`session: refresh` + `pass_previous_response: false`）

## エージェント対応表（ol-soldiers ↔ ol-soldiers-style）

| ol-soldiers | ol-soldiers-style | 責務 |
|-------------|-------------------|------|
| Commander | commander (persona) / intake step | 目的・Done 定義、情報不足エスカレーション |
| Sergeant | sergeant (persona) / plan_split + execute team_leader + completion_check | タスク分割、並列割当、完了確認 |
| Soldier | soldier (persona) / execute の part_persona | 単一タスク実装 |
| Inspector | task-inspector (persona) / task_review step | タスク単位の独立評価 |
| （新規） | goal-inspector (persona) / goal_review step | サイクル終端の目的 AND テスト判定 |
| （新規） | facilitator (persona) / summarize_cycle + escalate_* + loop monitor | サイクル間要約・エスカレーション要約 |

## 期待される出力

`.takt/runs/<run>/reports/` 配下に以下が生成される（takt 既定のレポートディレクトリ）。

- `intake.md` — 目的と Done 定義（統一スキーマ: source / title / body / acceptance_signals）
- `plan-split.md` — タスクリスト（purpose / acceptance_criteria / related_files / dependencies / parallel_ok / context_digest）
- `execute.md` — 各 Soldier の status / summary / files_modified / issues
- `task-review.md` — verdict 3 値（approved / needs_revision / rejected）+ findings（severity × category）
- `completion-check.md` — all_approved フラグと集計
- `goal-review.md` — verdict 3 値（approved / needs_more_cycles / blocked）+ tests_passed + test_command
- `cycle-summary.md` — サイクル番号 + 5 要素（目的 / 達成状況 / 決定事項 / 未解決課題 / 成果物ポインタ）
- `escalate-summary.md` — 停止理由 / これまでの成果物 / ブロッカー / ユーザーへの質問（1〜3 項目）

## エスカレーション時の再開手順

以下 3 トリガーで停止する（`requires_user_input: true` + `interactive_only: true`）:

1. 情報不足（intake で Commander が検知）
2. 判断詰まり（Soldier / Sergeant が実装中に詰まる、Goal Inspector が blocked）
3. サイクル上限超過（loop_monitors が threshold: 3 到達で escalate_cycle_limit にルーティング）

ユーザーが回答を与えると、takt engine の resume_point により同一 run を再開できる。回答方法は takt 標準の対話モードに従う。

## 汎用性の担保

- テストコマンドはハードコードしない（Goal Inspector が `package.json` / `pyproject.toml` / `Cargo.toml` / `Makefile` 等の規約から動的に特定）
- ol-soldiers の `inbox_write.sh` / `get_agent_id.sh` 等の通信スクリプトは持ち込まない（takt engine の責務と重複するため）
- 言語・フレームワーク固有の前提は persona / instruction / workflow のどこにも書かない
