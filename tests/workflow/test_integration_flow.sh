#!/bin/bash
# tests/workflow/test_integration_flow.sh - ワークフロー全フェーズの疎通確認
#
# 単体テストは個別の step / persona / instruction を検証する。ここでは
# 「intake → plan_split → execute → task_review → completion_check →
#  goal_review → (summarize_cycle → plan_split) | escalate_*」という
# 複数モジュール横断のデータフロー全体が、ルール配線として成立するかを検証する。
#
# これは単純な grep を超えた、phase 間遷移の合流・分岐・ループ条件の検証である。

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

# intake の遷移先に plan_split と escalate_info_gap が含まれる
test_start "intake から plan_split への通常遷移が定義されている"
targets="$(next_targets_of intake)"
if grep -qxF plan_split <<<"$targets"; then
    _record_pass
else
    _record_fail "intake → plan_split 遷移がない (targets: $(tr '\n' ',' <<<"$targets"))"
fi

test_start "intake から escalate_info_gap への遷移が定義されている (情報不足時)"
if grep -qxF escalate_info_gap <<<"$targets"; then
    _record_pass
else
    # intake 自身に留まる requires_user_input: true パターンも許容
    intake_rules="$("$YQ" "$WORKFLOW_YAML" '.steps[] | select(.name == "intake") | .rules' 2>/dev/null || true)"
    if grep -q 'requires_user_input' <<<"$intake_rules"; then
        _record_pass
    else
        _record_fail "intake から escalate_info_gap への遷移がない"
    fi
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

# goal_review 分岐: COMPLETE / summarize_cycle (needs_more_cycles) / escalate_blocked
test_start "goal_review から COMPLETE への遷移が定義されている"
targets="$(next_targets_of goal_review)"
if grep -qxF COMPLETE <<<"$targets"; then
    _record_pass
else
    _record_fail "goal_review → COMPLETE 遷移がない"
fi

test_start "goal_review から summarize_cycle への遷移が定義されている"
if grep -qxF summarize_cycle <<<"$targets"; then
    _record_pass
else
    _record_fail "goal_review → summarize_cycle 遷移がない"
fi

test_start "goal_review から escalate_blocked への遷移が定義されている"
if grep -qxF escalate_blocked <<<"$targets"; then
    _record_pass
else
    _record_fail "goal_review → escalate_blocked 遷移がない"
fi

# summarize_cycle → plan_split (サイクル再開)
test_start "summarize_cycle から plan_split への遷移が定義されている"
targets="$(next_targets_of summarize_cycle)"
if grep -qxF plan_split <<<"$targets"; then
    _record_pass
else
    _record_fail "summarize_cycle → plan_split 遷移がない (サイクルが繋がらない)"
fi

# loop_monitors が plan_split → goal_review サイクルを escalate_cycle_limit にルーティングする
test_start "loop_monitors の judge.rules に escalate_cycle_limit への遷移がある"
monitor_rules="$("$YQ" "$WORKFLOW_YAML" '.loop_monitors[].judge.rules' 2>/dev/null || true)"
if grep -q 'escalate_cycle_limit' <<<"$monitor_rules"; then
    _record_pass
else
    _record_fail "loop_monitors judge rules に escalate_cycle_limit 遷移がない (サイクル上限が強制されない)"
fi

# escalate_* ステップは終端 (外へ次遷移しない / 自分自身に戻って user_input)
test_start "escalate_info_gap は終端扱い (自身に留まる or COMPLETE/ABORT 以外の次 step に出ない)"
targets="$(next_targets_of escalate_info_gap)"
# escalate_* は requires_user_input: true で自己ループするか、ABORT で終わるのが許容形
invalid=""
while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    case "$t" in
        escalate_info_gap|COMPLETE|ABORT) ;;
        *) invalid="${invalid}${t} " ;;
    esac
done <<<"$targets"
if [[ -z "$invalid" ]]; then
    _record_pass
else
    _record_fail "escalate_info_gap が通常 step に遷移している (許容は自身/COMPLETE/ABORT のみ): $invalid"
fi

test_start "escalate_blocked は終端扱い"
targets="$(next_targets_of escalate_blocked)"
invalid=""
while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    case "$t" in
        escalate_blocked|COMPLETE|ABORT) ;;
        *) invalid="${invalid}${t} " ;;
    esac
done <<<"$targets"
if [[ -z "$invalid" ]]; then
    _record_pass
else
    _record_fail "escalate_blocked が通常 step に遷移している: $invalid"
fi

test_start "escalate_cycle_limit は終端扱い"
targets="$(next_targets_of escalate_cycle_limit)"
invalid=""
while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    case "$t" in
        escalate_cycle_limit|COMPLETE|ABORT) ;;
        *) invalid="${invalid}${t} " ;;
    esac
done <<<"$targets"
if [[ -z "$invalid" ]]; then
    _record_pass
else
    _record_fail "escalate_cycle_limit が通常 step に遷移している: $invalid"
fi

print_summary
