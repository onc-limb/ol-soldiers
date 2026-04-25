#!/bin/bash
# tests/feature-doc/test_workflow_yaml.sh - feature-doc workflow YAML のコントラクト検証
#
# plan.md で固定されたステップ構成・遷移・並列ブロック・loop_monitors・edit 権限などを、
# takt 同梱の yaml パーサで直接読み取って検証する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

YQ="$SCRIPT_DIR/../lib/run_yaml_query.sh"
WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/feature-doc.yaml"

if [[ ! -f "$WORKFLOW_YAML" ]]; then
    echo "  (skip) feature-doc workflow YAML not yet created: $WORKFLOW_YAML"
    print_summary
    exit $?
fi

query() { "$YQ" "$WORKFLOW_YAML" "$@"; }

test_start "name が feature-doc である"
actual="$(query '.name' 2>/dev/null || echo '<missing>')"
assert_equals "feature-doc" "$actual" "workflow.name"

test_start "initial_step が plan である"
actual="$(query '.initial_step' 2>/dev/null || echo '<missing>')"
assert_equals "plan" "$actual" "workflow.initial_step"

test_start "description に機能ドキュメント生成の目的が明記されている"
# Why: ワークフロー一覧から「機能ドキュメント生成」と分かる description が必要。
desc="$(query '.description' 2>/dev/null || echo '')"
if grep -qE "機能|ドキュメント|doc" <<<"$desc"; then
    _record_pass
else
    _record_fail "description に機能ドキュメント生成の説明がない (found: $desc)"
fi

test_start "必須の親 step がすべて定義されている"
# Why: plan → investigate → write_docs (parallel 親) → review → fix の 5 親 step。
steps="$(query '.steps[].name' 2>/dev/null || true)"
for required in plan investigate write_docs review fix; do
    if grep -qxE "$required" <<<"$steps"; then
        _record_pass
    else
        _record_fail "steps に $required が存在しない"
    fi
done

test_start "plan step の edit が false である"
# Why: 計画段階ではコード / ドキュメント編集を許さない（要件 18）。
value="$(query '.steps[] | select(.name == "plan") | .edit' 2>/dev/null || echo '<missing>')"
assert_equals "false" "$value" "plan.edit"

test_start "investigate step の edit が false である"
# Why: 調査段階はプロダクションコード変更禁止（要件 19）。
value="$(query '.steps[] | select(.name == "investigate") | .edit' 2>/dev/null || echo '<missing>')"
assert_equals "false" "$value" "investigate.edit"

test_start "review step の edit が false である"
# Why: レビューは指摘のみ、ドキュメント本体は編集不可（要件 22）。
value="$(query '.steps[] | select(.name == "review") | .edit' 2>/dev/null || echo '<missing>')"
assert_equals "false" "$value" "review.edit"

test_start "fix step の edit が true である"
# Why: fix は生成済みドキュメントを修正する（要件 23）。
value="$(query '.steps[] | select(.name == "fix") | .edit' 2>/dev/null || echo '<missing>')"
assert_equals "true" "$value" "fix.edit"

test_start "write_docs が parallel ブロックを持つ"
parallel_names="$(query '.steps[] | select(.name == "write_docs") | .parallel[].name' 2>/dev/null || true)"
if [[ -z "$parallel_names" ]]; then
    _record_fail "write_docs に parallel 配下のサブステップがない"
else
    for required in write_user_doc write_detail_doc; do
        if grep -qxE "$required" <<<"$parallel_names"; then
            _record_pass
        else
            _record_fail "write_docs の parallel に $required がない"
        fi
    done
fi

test_start "write_user_doc サブステップの edit が true である"
value="$(query '.steps[] | select(.name == "write_docs") | .parallel[] | select(.name == "write_user_doc") | .edit' 2>/dev/null || echo '<missing>')"
assert_equals "true" "$value" "write_user_doc.edit"

test_start "write_detail_doc サブステップの edit が true である"
value="$(query '.steps[] | select(.name == "write_docs") | .parallel[] | select(.name == "write_detail_doc") | .edit' 2>/dev/null || echo '<missing>')"
assert_equals "true" "$value" "write_detail_doc.edit"

test_start "write_user_doc サブステップが user-doc-write.md を生成する"
# Why: review/fix instruction が {report:user-doc-write.md} で参照するため、
# parallel サブステップ側で生成保証がないと engine が空文字列を埋め込んで指示が崩れる。
value="$(query '.steps[] | select(.name == "write_docs") | .parallel[] | select(.name == "write_user_doc") | .output_contracts.report[].name' 2>/dev/null || echo '')"
if grep -qxF "user-doc-write.md" <<<"$value"; then
    _record_pass
else
    _record_fail "write_user_doc.output_contracts.report[].name に user-doc-write.md がない (found: $value)"
fi

test_start "write_detail_doc サブステップが detail-doc-write.md を生成する"
# Why: review/fix instruction が {report:detail-doc-write.md} で参照するため、
# parallel サブステップ側で生成保証がないと engine が空文字列を埋め込んで指示が崩れる。
value="$(query '.steps[] | select(.name == "write_docs") | .parallel[] | select(.name == "write_detail_doc") | .output_contracts.report[].name' 2>/dev/null || echo '')"
if grep -qxF "detail-doc-write.md" <<<"$value"; then
    _record_pass
else
    _record_fail "write_detail_doc.output_contracts.report[].name に detail-doc-write.md がない (found: $value)"
fi

test_start "parallel サブステップの rules に next が定義されていない（アンチパターン検出）"
# Why: parallel サブステップの遷移は親 step の集約 rules（all/any）で決める。
# サブ側に next を書くと engine の集約判定と競合するため禁止する。
sub_next="$(query '.steps[] | select(.name == "write_docs") | .parallel[].rules[].next' 2>/dev/null | sed '/^$/d' || true)"
if [[ -z "$sub_next" ]]; then
    _record_pass
else
    _record_fail "parallel サブステップの rules に next が定義されている: $sub_next"
fi

test_start "write_docs 親の rules に all(\"執筆完了\") が含まれる"
# Why: 両サブが完了したら review へ。parallel の集約条件は all() / any()（要件 7 / 集約ルール）。
parent_rules="$(query '.steps[] | select(.name == "write_docs") | .rules' 2>/dev/null || true)"
if grep -q 'all(' <<<"$parent_rules"; then
    _record_pass
else
    _record_fail "write_docs の rules に all() 集約条件がない"
fi

test_start "write_docs 親の rules に any(\"執筆失敗\") が含まれる"
if grep -q 'any(' <<<"$parent_rules"; then
    _record_pass
else
    _record_fail "write_docs の rules に any() 集約条件がない"
fi

test_start "fix step が pass_previous_response: false を持つ"
# Why: review 結果を {report:doc-review.md} で明示参照するため、直前レスポンスに依存させない。
value="$(query '.steps[] | select(.name == "fix") | .pass_previous_response' 2>/dev/null || echo '<missing>')"
assert_equals "false" "$value" "fix.pass_previous_response"

test_start "loop_monitors に review + fix サイクルが定義されている"
# Why: 無限ループ防止のため。既存 takt-default.yaml / ol-soldiers-style.yaml と同仕組み。
cycles_json="$(query '.loop_monitors[].cycle' 2>/dev/null || true)"
if grep -q 'review' <<<"$cycles_json" && grep -q 'fix' <<<"$cycles_json"; then
    _record_pass
else
    _record_fail "loop_monitors.cycle に review / fix の組が存在しない (found: $cycles_json)"
fi

test_start "loop_monitors の threshold が 3 である"
# Why: 計画レポートで「既存最小値 3 に揃える」と明示。
thresholds="$(query '.loop_monitors[].threshold' 2>/dev/null || true)"
if grep -qxE '3' <<<"$thresholds"; then
    _record_pass
else
    _record_fail "loop_monitors に threshold=3 が存在しない (found: $thresholds)"
fi

test_start "plan → investigate 遷移が rules で定義されている"
plan_rules="$(query '.steps[] | select(.name == "plan") | .rules' 2>/dev/null || true)"
if grep -q '"next":"investigate"' <<<"$plan_rules"; then
    _record_pass
else
    _record_fail "plan → investigate 遷移がない"
fi

test_start "investigate → write_docs 遷移が rules で定義されている"
inv_rules="$(query '.steps[] | select(.name == "investigate") | .rules' 2>/dev/null || true)"
if grep -q '"next":"write_docs"' <<<"$inv_rules"; then
    _record_pass
else
    _record_fail "investigate → write_docs 遷移がない"
fi

test_start "review の rules に COMPLETE 遷移がある（指摘なし）"
review_rules="$(query '.steps[] | select(.name == "review") | .rules' 2>/dev/null || true)"
if grep -q 'COMPLETE' <<<"$review_rules"; then
    _record_pass
else
    _record_fail "review → COMPLETE 遷移がない"
fi

test_start "review の rules に fix 遷移がある（指摘あり）"
if grep -q '"next":"fix"' <<<"$review_rules"; then
    _record_pass
else
    _record_fail "review → fix 遷移がない"
fi

test_start "fix の rules に review 遷移がある（修正完了 → 再レビュー）"
fix_rules="$(query '.steps[] | select(.name == "fix") | .rules' 2>/dev/null || true)"
if grep -q '"next":"review"' <<<"$fix_rules"; then
    _record_pass
else
    _record_fail "fix → review 遷移がない"
fi

print_summary
