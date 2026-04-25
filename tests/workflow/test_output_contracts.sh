#!/bin/bash
# tests/workflow/test_output_contracts.sh - output-contract ファイルの必須フィールド検証

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

CONTRACT_DIR="$REPO_ROOT/.takt/facets/output-contracts"

# intake: 統一スキーマ (source / title / body / acceptance_signals)
intake="$CONTRACT_DIR/intake.md"
test_start "output-contracts/intake.md が統一入力スキーマ (source/title/body/acceptance_signals) を定義する"
assert_contains "$intake" "source" "source"
assert_contains "$intake" "title" "title"
assert_contains "$intake" "body" "body"
assert_contains "$intake" "acceptance_signals|受け入れ" "acceptance_signals"

# plan-split: タスク必須フィールド
plan_split="$CONTRACT_DIR/plan-split.md"
test_start "output-contracts/plan-split.md が各タスクに purpose / acceptance_criteria / related_files / dependencies / parallel_ok を要求する"
assert_contains "$plan_split" "purpose|目的" "purpose"
assert_contains "$plan_split" "acceptance_criteria|受け入れ条件" "acceptance_criteria"
assert_contains "$plan_split" "related_files|関連ファイル" "related_files"
assert_contains "$plan_split" "dependencies|依存" "dependencies"
assert_contains "$plan_split" "parallel_ok|並列" "parallel_ok"

# execute: 各 soldier 成果物の報告
execute="$CONTRACT_DIR/execute.md"
test_start "output-contracts/execute.md が files_modified / status / summary を要求する"
assert_contains "$execute" "files_modified|変更ファイル" "files_modified"
assert_contains "$execute" "status" "status"
assert_contains "$execute" "summary|要約" "summary"

# task-review: verdict + findings
task_review="$CONTRACT_DIR/task-review.md"
test_start "output-contracts/task-review.md が verdict 3 値と findings を要求する"
assert_contains "$task_review" "verdict" "verdict"
assert_contains "$task_review" "approved" "approved"
assert_contains "$task_review" "needs_revision" "needs_revision"
assert_contains "$task_review" "rejected" "rejected"
assert_contains "$task_review" "findings|発見事項" "findings"
assert_contains "$task_review" "severity|重要度" "severity"

# completion-check: all_approved フラグ
completion_check="$CONTRACT_DIR/completion-check.md"
test_start "output-contracts/completion-check.md が全完了フラグを要求する"
assert_contains "$completion_check" "all_approved|all_done|完了|全.*approved" "全完了フラグ"

# goal-review: verdict 3 値 + テスト結果
goal_review="$CONTRACT_DIR/goal-review.md"
test_start "output-contracts/goal-review.md が verdict 3 値を要求する"
assert_contains "$goal_review" "approved" "approved"
assert_contains "$goal_review" "needs_more_cycles" "needs_more_cycles"
assert_contains "$goal_review" "blocked" "blocked"

test_start "output-contracts/goal-review.md がテスト実行結果の報告を要求する"
assert_contains "$goal_review" "tests?_passed|テスト.*結果|テスト.*通過" "テスト結果"

# cycle-summary: 5 要素
cycle_summary="$CONTRACT_DIR/cycle-summary.md"
test_start "output-contracts/cycle-summary.md が 5 要素 (目的/達成状況/決定事項/未解決課題/成果物) を要求する"
assert_contains "$cycle_summary" "目的" "目的"
assert_contains "$cycle_summary" "達成状況|達成条件" "達成状況"
assert_contains "$cycle_summary" "決定事項" "決定事項"
assert_contains "$cycle_summary" "未解決|残課題" "未解決課題"
assert_contains "$cycle_summary" "成果物|ポインタ" "成果物ポインタ"

test_start "output-contracts/cycle-summary.md がサイクル番号を要求する"
assert_contains "$cycle_summary" "サイクル.*番号|cycle.*number|cycle_count" "サイクル番号"

# escalate-summary: 4 要素
escalate_summary="$CONTRACT_DIR/escalate-summary.md"
test_start "output-contracts/escalate-summary.md が 4 要素 (停止理由/成果物/ブロッカー/質問) を要求する"
assert_contains "$escalate_summary" "停止.*理由|理由|reason" "停止理由"
assert_contains "$escalate_summary" "成果物|これまで" "成果物"
assert_contains "$escalate_summary" "ブロッカー|blocker" "ブロッカー"
assert_contains "$escalate_summary" "質問|確認したい" "質問"

test_start "output-contracts/escalate-summary.md が質問数を 1-3 項目に制限している"
# Why: 計画レポートで「ユーザーに確認したいこと (1-3 項目)」と明示されている。
assert_contains "$escalate_summary" "1.*3|3 ?項目|3 ?件|最大 ?3" "1-3 項目制限"

print_summary
