#!/bin/bash
# tests/workflow/test_integration_flow.sh - ワークフロー全フェーズの疎通確認
#
# 単体テストは個別の step / persona / instruction を検証する。ここでは
# 「intake → plan_split → execute → task_review → completion_check →
#  goal_review → (summarize_cycle → plan_split) | pr_create → COMPLETE」という
# 複数モジュール横断のデータフロー全体が、ルール配線として成立するかを検証する。
#
# 新仕様: 情報不足や blocker でユーザーへ質問せず、PR 本文に明記して pr_create で完結する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

YQ="$SCRIPT_DIR/../lib/run_yaml_query.sh"
WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/ol-soldiers-style.yaml"

if [[ ! -f "$WORKFLOW_YAML" ]]; then
    echo "  (skip) workflow YAML not yet created"
    print_summary
    exit $?
fi

# 指定 step から出る next の集合を返す (COMPLETE / ABORT も含む)
next_targets_of() {
    local step="$1"
    "$YQ" "$WORKFLOW_YAML" ".steps[] | select(.name == \"$step\") | .rules" 2>/dev/null \
        | grep -oE '"next":"[^"]+"' \
        | sed -E 's/"next":"([^"]+)"/\1/' \
        | sort -u
}

# intake → plan_split の単一遷移（情報不足時もエスカレーションしない）
test_start "intake から plan_split への遷移が定義されている"
targets="$(next_targets_of intake)"
if grep -qxF plan_split <<<"$targets"; then
    _record_pass
else
    _record_fail "intake → plan_split 遷移がない (targets: $(tr '\n' ',' <<<"$targets"))"
fi

test_start "intake が escalate_info_gap への分岐を持たない"
# Why: 新仕様では情報不足でもユーザーへ質問せず assumptions / open_questions に記録して進む。
if grep -qxF escalate_info_gap <<<"$targets"; then
    _record_fail "intake から escalate_info_gap への遷移が残存している"
else
    _record_pass
fi

# plan_split → execute
test_start "plan_split から execute への遷移が定義されている"
targets="$(next_targets_of plan_split)"
if grep -qxF execute <<<"$targets"; then
    _record_pass
else
    _record_fail "plan_split → execute 遷移がない"
fi

# execute → task_review
test_start "execute から task_review への遷移が定義されている"
targets="$(next_targets_of execute)"
if grep -qxF task_review <<<"$targets"; then
    _record_pass
else
    _record_fail "execute → task_review 遷移がない"
fi

# task_review → execute (差し戻し) / completion_check (全 approved)
test_start "task_review から execute (差し戻し) への遷移が定義されている"
targets="$(next_targets_of task_review)"
if grep -qxF execute <<<"$targets"; then
    _record_pass
else
    _record_fail "task_review → execute 差し戻し遷移がない"
fi

test_start "task_review から completion_check への遷移が定義されている"
if grep -qxF completion_check <<<"$targets"; then
    _record_pass
else
    _record_fail "task_review → completion_check 遷移がない"
fi

# completion_check → goal_review
test_start "completion_check から goal_review への遷移が定義されている"
targets="$(next_targets_of completion_check)"
if grep -qxF goal_review <<<"$targets"; then
    _record_pass
else
    _record_fail "completion_check → goal_review 遷移がない"
fi

# goal_review 分岐: pr_create (approved / blocked) / summarize_cycle (needs_more_cycles)
test_start "goal_review から pr_create への遷移が定義されている (approved / blocked 共に)"
targets="$(next_targets_of goal_review)"
if grep -qxF pr_create <<<"$targets"; then
    _record_pass
else
    _record_fail "goal_review → pr_create 遷移がない"
fi

test_start "goal_review から summarize_cycle への遷移が定義されている"
if grep -qxF summarize_cycle <<<"$targets"; then
    _record_pass
else
    _record_fail "goal_review → summarize_cycle 遷移がない"
fi

test_start "goal_review が escalate_blocked への分岐を持たない"
# Why: 新仕様では blocked でも pr_create に進み、blocker を PR 本文に明記する。
if grep -qxF escalate_blocked <<<"$targets"; then
    _record_fail "goal_review から escalate_blocked への遷移が残存している"
else
    _record_pass
fi

# summarize_cycle → plan_split (サイクル再開)
test_start "summarize_cycle から plan_split への遷移が定義されている"
targets="$(next_targets_of summarize_cycle)"
if grep -qxF plan_split <<<"$targets"; then
    _record_pass
else
    _record_fail "summarize_cycle → plan_split 遷移がない (サイクルが繋がらない)"
fi

# loop_monitors が plan_split → goal_review サイクルを pr_create にルーティングする
test_start "loop_monitors の judge.rules に pr_create への遷移がある (サイクル上限到達時)"
monitor_rules="$("$YQ" "$WORKFLOW_YAML" '.loop_monitors[].judge.rules' 2>/dev/null || true)"
if grep -q 'pr_create' <<<"$monitor_rules"; then
    _record_pass
else
    _record_fail "loop_monitors judge rules に pr_create 遷移がない (サイクル上限が PR で確定しない)"
fi

test_start "loop_monitors の judge.rules に escalate_cycle_limit が残存していない"
# Why: 新仕様ではサイクル上限到達でもユーザーへ質問せず pr_create で確定する。
if grep -q 'escalate_cycle_limit' <<<"$monitor_rules"; then
    _record_fail "loop_monitors judge rules に旧 escalate_cycle_limit 遷移が残存している"
else
    _record_pass
fi

# pr_create → COMPLETE 終端
test_start "pr_create から COMPLETE への遷移が定義されている"
targets="$(next_targets_of pr_create)"
if grep -qxF COMPLETE <<<"$targets"; then
    _record_pass
else
    _record_fail "pr_create → COMPLETE 遷移がない (ワークフロー終端が確定しない)"
fi

# 旧 escalate_* step が完全に削除されている
test_start "旧 escalate_info_gap / escalate_blocked / escalate_cycle_limit step が存在しない"
all_steps="$("$YQ" "$WORKFLOW_YAML" '.steps[].name' 2>/dev/null || true)"
remaining=""
for forbidden in escalate_info_gap escalate_blocked escalate_cycle_limit; do
    if grep -qxF "$forbidden" <<<"$all_steps"; then
        remaining="${remaining}${forbidden} "
    fi
done
if [[ -z "$remaining" ]]; then
    _record_pass
else
    _record_fail "旧 escalate step が残存: $remaining"
fi

print_summary
