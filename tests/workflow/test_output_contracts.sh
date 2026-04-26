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

# pr-create: 完了状況 + PR URL + open_questions / blockers / assumptions
pr_create="$CONTRACT_DIR/pr-create.md"
test_start "output-contracts/pr-create.md が完了状況 (success / partial / blocked) を要求する"
# Why: 旧仕様の escalate-summary を置き換え。情報不足や blocker は PR 本文に明記して
#      ワークフローを完了させる設計。完了状況フィールドはレビュー時の最終判断材料。
assert_contains "$pr_create" "success" "success"
assert_contains "$pr_create" "partial" "partial"
assert_contains "$pr_create" "blocked" "blocked"

test_start "output-contracts/pr-create.md が PR URL を要求する"
assert_contains "$pr_create" "url|URL|PR.*url" "PR URL"

test_start "output-contracts/pr-create.md が assumptions / open_questions / blockers を要求する"
assert_contains "$pr_create" "assumptions" "assumptions"
assert_contains "$pr_create" "open_questions" "open_questions"
assert_contains "$pr_create" "blocker" "blockers"

# intake: 情報不足を assumptions / open_questions に持ち回る新仕様
test_start "output-contracts/intake.md が assumptions と open_questions のフィールドを要求する"
# Why: 新仕様では情報不足時もユーザーへ質問せず、assumptions と open_questions に記録して
#      PR 本文に転記する。これらフィールドは PR で最終確認するための持ち回りデータ。
assert_contains "$intake" "assumptions" "assumptions"
assert_contains "$intake" "open_questions" "open_questions"

print_summary
