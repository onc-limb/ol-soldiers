#!/bin/bash
# tests/workflow/test_instructions.sh - instruction ファイルの仕様検証
#
# 計画レポートが各 instruction に求めた振る舞い (URL 判定 / gh 呼び出し / AND 判定 /
# サイクル要約 / エスカレーション要約) がテキストに反映されているかを確認する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

INSTRUCTION_DIR="$REPO_ROOT/.takt/facets/instructions"

# intake: URL 判定と gh issue view の両方が含まれる必要がある
intake="$INSTRUCTION_DIR/intake.md"
test_start "intake.md が GitHub issue URL パターン判定を記述している"
assert_contains "$intake" "github\.com|issues/" "GitHub issue URL パターン"

test_start "intake.md が gh issue view を使った取得手順を記述している"
assert_contains "$intake" "gh issue view" "gh issue view コマンド"

test_start "intake.md が URL 以外は直接入力として扱う分岐を記述している"
assert_contains "$intake" "直接入力|plain text|それ以外" "直接入力フォールバック"

test_start "intake.md が情報不足時の取り扱い (assumptions / open_questions として記録) を記述している"
# Why: 旧仕様では escalate_info_gap で停止していたが、新仕様では assumptions / open_questions
# に記録して PR で確認に回す。停止せず先へ進める方針が反映されているかを確認。
assert_contains "$intake" "情報不足|assumptions|open_questions" "情報不足の取り扱い"
assert_contains "$intake" "停止せず|先へ進め|PR で確認" "停止しない方針"

# plan-split: 関連ファイル / 依存関係 / 並列可否を必須化する指示
plan_split="$INSTRUCTION_DIR/plan-split.md"
test_start "plan-split.md が 1 機能 1 関心事の粒度を指示している"
assert_contains "$plan_split" "1 ?機能|1 ?関心事|単一.*責務" "粒度指示"

test_start "plan-split.md が各タスクに関連ファイルリストを必須化している"
assert_contains "$plan_split" "関連ファイル|対象ファイル|related" "関連ファイル必須"

test_start "plan-split.md が依存関係と並列可否を明示させている"
assert_contains "$plan_split" "依存|dependencies" "依存関係"
assert_contains "$plan_split" "並列|parallel_ok|parallel" "並列可否"

test_start "plan-split.md が cycle-summary.md を 2 サイクル目以降のみ参照する条件分岐を持つ"
# Why: 初回サイクルでは cycle-summary.md は未生成。存在しない前提の参照は実行時エラー。
assert_contains "$plan_split" "cycle-summary" "cycle-summary.md 参照"
assert_contains "$plan_split" "存在する場合|初回|2.*サイクル|前サイクル" "条件分岐"

# execute-team-leader: 最大 3 並列 / Soldier に渡すコンテキストの限定
# Why: takt 0.37 の max_parts ハードキャップ (3) に合わせて、当初計画の「4 並列」を「3 並列」に下げる。
execute="$INSTRUCTION_DIR/execute-team-leader.md"
test_start "execute-team-leader.md が最大並列数 (takt 上限 3) を明示している"
assert_contains "$execute" "3 ?並列|max_parts.*3|最大 ?3" "3 並列"

test_start "execute-team-leader.md が各 part instruction に関連ファイル・前提情報のみ詰める指示を出す"
assert_contains "$execute" "関連ファイル|対象ファイル" "関連ファイル詰め込み"
assert_contains "$execute" "前提情報|前提|context|コンテキスト" "前提情報"

test_start "execute-team-leader.md が part 間の情報漏れを禁止している"
# Why: 他 part の状態を知らせない (ol-soldiers Soldier の独立性を翻案)。
assert_contains "$execute" "他.*part|他の.*タスク|他 ?Soldier|独立" "part 独立性"

# task-review: 3 値 verdict + severity
task_review="$INSTRUCTION_DIR/task-review.md"
test_start "task-review.md が approved/needs_revision/rejected の 3 値判定を指示する"
assert_contains "$task_review" "approved" "approved"
assert_contains "$task_review" "needs_revision" "needs_revision"
assert_contains "$task_review" "rejected" "rejected"

test_start "task-review.md が各発見に severity を付けるよう指示する"
# Why: ol-soldiers Inspector 仕様 (critical/major/minor/info) を踏襲。
assert_contains "$task_review" "severity|重要度|critical|major|minor" "severity 付与"

# goal-review: AND 判定 + テスト動的特定
goal_review="$INSTRUCTION_DIR/goal-review.md"
test_start "goal-review.md が目的達成 AND テスト通過の AND 判定を指示する"
assert_contains "$goal_review" "かつ|AND|両方" "AND 条件"
assert_contains "$goal_review" "テスト.*通過|テスト.*成功|tests?.*pass" "テスト通過"

test_start "goal-review.md がテストコマンドを動的特定する手順を含む"
assert_contains "$goal_review" "package\.json|pyproject\.toml|Cargo\.toml|Makefile" "動的特定"

test_start "goal-review.md がテストコマンドをハードコードしていない"
# Why: 汎用ワークフローなので npm test 等は instruction 内に固定で書かない。
# 例示コードブロック内は許容 (説明のため) だが、唯一の手段として書かないこと。
# ここでは厳密チェックは persona 側で行い、instruction では「規約から特定」文言の有無で代替。
assert_contains "$goal_review" "規約|特定|look up|検出" "プロジェクト規約からの特定"

# cycle-summary: 保持すべき最小情報
cycle_summary="$INSTRUCTION_DIR/cycle-summary.md"
test_start "cycle-summary.md が目的・達成状況・決定事項・未解決課題・成果物ポインタの要約を指示する"
assert_contains "$cycle_summary" "目的" "目的"
assert_contains "$cycle_summary" "達成状況|達成条件" "達成状況"
assert_contains "$cycle_summary" "決定事項" "決定事項"
assert_contains "$cycle_summary" "未解決|残課題" "未解決課題"
assert_contains "$cycle_summary" "成果物|ポインタ" "成果物ポインタ"

test_start "cycle-summary.md が生の思考・探索ログを捨てる方針を明記する"
# Why: 中間成果を次サイクルに流さない要件の担保。
assert_contains "$cycle_summary" "生の|思考|探索ログ|中間成果|破棄|捨" "中間成果破棄"

# pr-create: PR 本文に open_questions / blockers / assumptions を転記する責務
pr_create="$INSTRUCTION_DIR/pr-create.md"
test_start "pr-create.md が PR 本文に assumptions / open_questions / blockers を必ず含める指示を持つ"
# Why: 旧仕様の escalate-summary（ユーザー対話で停止）を置き換え、停止せず PR 本文に
# 不足情報を明記する責務へ転換。PR レビュー時にユーザーが回答する設計。
assert_contains "$pr_create" "assumptions" "assumptions 転記"
assert_contains "$pr_create" "open_questions|ユーザー確認|質問" "open_questions 転記"
assert_contains "$pr_create" "blocker" "blockers 転記"
assert_contains "$pr_create" "gh pr create" "gh pr create コマンド"

test_start "pr-create.md が完了状況 (success / partial / blocked) の判定基準を記述している"
assert_contains "$pr_create" "success" "success"
assert_contains "$pr_create" "partial" "partial"
assert_contains "$pr_create" "blocked" "blocked"

# loop-monitor-cycle: cycle_count 展開
loop_monitor="$INSTRUCTION_DIR/loop-monitor-cycle.md"
test_start "loop-monitor-cycle.md が cycle_count プレースホルダを参照する"
assert_contains "$loop_monitor" "cycle_count|サイクル数|ループ回数" "cycle_count"

test_start "loop-monitor-cycle.md がサイクル 3 到達時の escalation 判断を含む"
assert_contains "$loop_monitor" "3.*サイクル|3 ?回|threshold.*3|サイクル上限" "サイクル 3 判定"

# completion-check: 全 approved 判定
completion_check="$INSTRUCTION_DIR/completion-check.md"
test_start "completion-check.md が全タスク approved 確認を指示する"
assert_contains "$completion_check" "全.*approved|すべて.*approved|完了|完遂" "全 approved 判定"

print_summary
