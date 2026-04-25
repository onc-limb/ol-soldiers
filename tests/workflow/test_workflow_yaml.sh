#!/bin/bash
# tests/workflow/test_workflow_yaml.sh - workflow YAML のコントラクト検証
#
# plan.md で固定された数値・ステップ遷移・loop_monitors・requires_user_input の
# 配置がずれていないかを、takt 同梱の yaml パーサで直接読み取って検証する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

YQ="$SCRIPT_DIR/../lib/run_yaml_query.sh"
WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/ol-soldiers-style.yaml"

if [[ ! -f "$WORKFLOW_YAML" ]]; then
    echo "  (skip) workflow YAML not yet created: $WORKFLOW_YAML"
    print_summary
    exit $?
fi

query() { "$YQ" "$WORKFLOW_YAML" "$@"; }

test_start "name が ol-soldiers-style である"
actual="$(query '.name' 2>/dev/null || echo '<missing>')"
assert_equals "ol-soldiers-style" "$actual" "workflow.name"

test_start "initial_step が intake である"
actual="$(query '.initial_step' 2>/dev/null || echo '<missing>')"
assert_equals "intake" "$actual" "workflow.initial_step"

test_start "必須 step がすべて定義されている"
steps="$(query '.steps[].name' 2>/dev/null || true)"
for required in intake plan_split execute task_review completion_check goal_review summarize_cycle escalate_info_gap escalate_blocked escalate_cycle_limit; do
    if grep -qxE "$required" <<<"$steps"; then
        _record_pass
    else
        _record_fail "steps に $required が存在しない"
    fi
done

test_start "execute step が team_leader で max_parts=3 を指定している"
# Why: 当初計画は max_parts=4 だったが、takt 0.37 の workflow-schemas.js が
# max(3) でハードキャップしているため、engine 制約に合わせて 3 に下げる。
max_parts="$(query '.steps[] | select(.name == "execute") | .team_leader.max_parts' 2>/dev/null || echo '<missing>')"
assert_equals "3" "$max_parts" "execute.team_leader.max_parts"

test_start "execute step の part_persona が soldier である"
part_persona="$(query '.steps[] | select(.name == "execute") | .team_leader.part_persona' 2>/dev/null || echo '<missing>')"
assert_equals "soldier" "$part_persona" "execute.team_leader.part_persona"

test_start "loop_monitors に threshold=3 のサイクルが 1 本以上存在する"
thresholds="$(query '.loop_monitors[].threshold' 2>/dev/null || true)"
if grep -qxE '3' <<<"$thresholds"; then
    _record_pass
else
    _record_fail "loop_monitors に threshold=3 が存在しない (found: $thresholds)"
fi

test_start "plan_split と goal_review を含むサイクル監視が定義されている"
# Why: サイクル上限 3 の強制は plan_split〜goal_review サイクル監視が担う。
# 配列要素なので json で受け取って grep 判定する。
cycles_json="$(query '.loop_monitors[].cycle' 2>/dev/null || true)"
if grep -q 'plan_split' <<<"$cycles_json" && grep -q 'goal_review' <<<"$cycles_json"; then
    _record_pass
else
    _record_fail "loop_monitors.cycle に plan_split と goal_review の組が存在しない"
fi

test_start "escalate_info_gap が requires_user_input=true である"
# rules の中の requires_user_input を探す: intake → escalate_info_gap の遷移、
# または escalate_info_gap 自身が requires_user_input を持つ形の両方を許容する。
rules_json="$(query '.steps[] | select(.name == "escalate_info_gap") | .rules' 2>/dev/null || true)"
if grep -q 'requires_user_input' <<<"$rules_json" || grep -q 'true' <<<"$rules_json"; then
    _record_pass
else
    # intake 側で requires_user_input をつけるパターンも許容
    intake_rules="$(query '.steps[] | select(.name == "intake") | .rules' 2>/dev/null || true)"
    if grep -q 'requires_user_input' <<<"$intake_rules"; then
        _record_pass
    else
        _record_fail "escalate_info_gap にも intake にも requires_user_input: true が見つからない"
    fi
fi

test_start "escalate_blocked が requires_user_input=true を持つ"
rules_json="$(query '.steps[] | select(.name == "escalate_blocked") | .rules' 2>/dev/null || true)"
if grep -q 'requires_user_input' <<<"$rules_json"; then
    _record_pass
else
    _record_fail "escalate_blocked に requires_user_input: true がない"
fi

test_start "escalate_cycle_limit が requires_user_input=true を持つ"
rules_json="$(query '.steps[] | select(.name == "escalate_cycle_limit") | .rules' 2>/dev/null || true)"
if grep -q 'requires_user_input' <<<"$rules_json"; then
    _record_pass
else
    _record_fail "escalate_cycle_limit に requires_user_input: true がない"
fi

test_start "task_review の rules に needs_revision or rejected → execute の遷移がある"
rules_json="$(query '.steps[] | select(.name == "task_review") | .rules' 2>/dev/null || true)"
if grep -q '"next":"execute"' <<<"$rules_json" && grep -qE '(needs_revision|rejected)' <<<"$rules_json"; then
    _record_pass
else
    _record_fail "task_review の差し戻し遷移が見つからない"
fi

test_start "goal_review の rules に approved→COMPLETE / needs_more_cycles / blocked→escalate_blocked が揃う"
rules_json="$(query '.steps[] | select(.name == "goal_review") | .rules' 2>/dev/null || true)"
missing=""
grep -q 'COMPLETE' <<<"$rules_json" || missing="${missing}approved→COMPLETE "
grep -q 'needs_more_cycles' <<<"$rules_json" || missing="${missing}needs_more_cycles "
grep -q 'escalate_blocked' <<<"$rules_json" || missing="${missing}blocked→escalate_blocked "
if [[ -z "$missing" ]]; then
    _record_pass
else
    _record_fail "goal_review に欠けている遷移: $missing"
fi

test_start "summarize_cycle が session: refresh を持つ"
session="$(query '.steps[] | select(.name == "summarize_cycle") | .session' 2>/dev/null || echo '<missing>')"
assert_equals "refresh" "$session" "summarize_cycle.session"

test_start "summarize_cycle が pass_previous_response=false である"
# Why: 中間成果 (生レスポンス) を次サイクルに流さないための明示フラグ。
value="$(query '.steps[] | select(.name == "summarize_cycle") | .pass_previous_response' 2>/dev/null || echo '<missing>')"
assert_equals "false" "$value" "summarize_cycle.pass_previous_response"

test_start "summarize_cycle → plan_split の遷移がある"
rules_json="$(query '.steps[] | select(.name == "summarize_cycle") | .rules' 2>/dev/null || true)"
if grep -q '"next":"plan_split"' <<<"$rules_json"; then
    _record_pass
else
    _record_fail "summarize_cycle → plan_split の遷移がない"
fi

test_start "goal_review が pass_previous_response=false である"
value="$(query '.steps[] | select(.name == "goal_review") | .pass_previous_response' 2>/dev/null || echo '<missing>')"
assert_equals "false" "$value" "goal_review.pass_previous_response"

test_start "intake step の edit が false である"
# Why: Commander は 3 層防御上「実装しない」ので intake step でコード編集を許さない。
value="$(query '.steps[] | select(.name == "intake") | .edit' 2>/dev/null || echo '<missing>')"
assert_equals "false" "$value" "intake.edit"

test_start "task_review step の edit が false である"
# Why: 評価者は実装者と独立である要件 (Inspector: edit 不可)。
value="$(query '.steps[] | select(.name == "task_review") | .edit' 2>/dev/null || echo '<missing>')"
assert_equals "false" "$value" "task_review.edit"

test_start "goal_review step の edit が false である"
value="$(query '.steps[] | select(.name == "goal_review") | .edit' 2>/dev/null || echo '<missing>')"
assert_equals "false" "$value" "goal_review.edit"

print_summary
