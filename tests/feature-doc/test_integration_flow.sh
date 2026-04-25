#!/bin/bash
# tests/feature-doc/test_integration_flow.sh - feature-doc 全ステップの疎通確認
#
# 「plan → investigate → write_docs (parallel: write_user_doc, write_detail_doc)
#   → review → (COMPLETE | fix → review) | ABORT」という複数ステップ横断の
# データフローが、ルール配線として正しく成立しているかを検証する。
#
# これは単純な grep を超え、parallel 集約・review / fix サイクル・終端遷移
# を含む phase 間遷移の疎通を確かめる integration テスト。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

YQ="$SCRIPT_DIR/../lib/run_yaml_query.sh"
WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/feature-doc.yaml"

if [[ ! -f "$WORKFLOW_YAML" ]]; then
    echo "  (skip) feature-doc workflow YAML not yet created"
    print_summary
    exit $?
fi

# 指定 step から出る next の集合を返す（COMPLETE / ABORT 含む）
next_targets_of() {
    local step="$1"
    "$YQ" "$WORKFLOW_YAML" ".steps[] | select(.name == \"$step\") | .rules" 2>/dev/null \
        | grep -oE '"next":"[^"]+"' \
        | sed -E 's/"next":"([^"]+)"/\1/' \
        | sort -u
}

# plan → investigate
test_start "plan から investigate への通常遷移が定義されている"
targets="$(next_targets_of plan)"
if grep -qxF investigate <<<"$targets"; then
    _record_pass
else
    _record_fail "plan → investigate 遷移がない (targets: $(tr '\n' ',' <<<"$targets"))"
fi

# plan → ABORT（情報不足時）
test_start "plan から ABORT への遷移が定義されている（情報不足時）"
if grep -qxF ABORT <<<"$targets"; then
    _record_pass
else
    _record_fail "plan → ABORT 遷移がない（情報不足時のフォールバックがない）"
fi

# investigate → write_docs
test_start "investigate から write_docs への遷移が定義されている"
targets="$(next_targets_of investigate)"
if grep -qxF write_docs <<<"$targets"; then
    _record_pass
else
    _record_fail "investigate → write_docs 遷移がない"
fi

test_start "investigate から ABORT への遷移が定義されている（調査不能時）"
if grep -qxF ABORT <<<"$targets"; then
    _record_pass
else
    _record_fail "investigate → ABORT 遷移がない"
fi

# write_docs (parallel) → review
test_start "write_docs から review への遷移が rules で定義されている"
# Why: parallel 集約条件は文字列内に "all(" / "any(" を含むため targets 抽出で拾える。
targets="$(next_targets_of write_docs)"
if grep -qxF review <<<"$targets"; then
    _record_pass
else
    _record_fail "write_docs → review 遷移がない (targets: $(tr '\n' ',' <<<"$targets"))"
fi

test_start "write_docs から ABORT への遷移が rules で定義されている（失敗時）"
if grep -qxF ABORT <<<"$targets"; then
    _record_pass
else
    _record_fail "write_docs → ABORT 遷移がない"
fi

# review → COMPLETE / fix
test_start "review から COMPLETE への遷移が定義されている（指摘なし）"
targets="$(next_targets_of review)"
if grep -qxF COMPLETE <<<"$targets"; then
    _record_pass
else
    _record_fail "review → COMPLETE 遷移がない"
fi

test_start "review から fix への遷移が定義されている（指摘あり）"
if grep -qxF fix <<<"$targets"; then
    _record_pass
else
    _record_fail "review → fix 遷移がない"
fi

# fix → review（修正完了 → 再レビュー）
test_start "fix から review への遷移が定義されている（再レビューサイクル）"
targets="$(next_targets_of fix)"
if grep -qxF review <<<"$targets"; then
    _record_pass
else
    _record_fail "fix → review 遷移がない（サイクルが繋がらない）"
fi

test_start "fix から ABORT への遷移が定義されている（修正不能時）"
if grep -qxF ABORT <<<"$targets"; then
    _record_pass
else
    _record_fail "fix → ABORT 遷移がない"
fi

# loop_monitors → ABORT 経路（非生産的サイクル検知）
test_start "loop_monitors の judge.rules に ABORT 遷移がある"
# Why: review/fix サイクルが非生産的な場合に ABORT できるセーフティ。
monitor_rules="$("$YQ" "$WORKFLOW_YAML" '.loop_monitors[].judge.rules' 2>/dev/null || true)"
if grep -q 'ABORT' <<<"$monitor_rules"; then
    _record_pass
else
    _record_fail "loop_monitors judge rules に ABORT 遷移がない（サイクル上限が強制されない）"
fi

# loop_monitors → review へ戻る（健全時）
test_start "loop_monitors の judge.rules に review への復帰遷移がある（健全時）"
if grep -q 'review' <<<"$monitor_rules"; then
    _record_pass
else
    _record_fail "loop_monitors judge rules に review 復帰遷移がない"
fi

# 全 step の next が workflow に実在する step / 終端（COMPLETE / ABORT）を指す
test_start "全 step の next が workflow 内に実在する step または COMPLETE / ABORT を指す"
defined_steps="$("$YQ" "$WORKFLOW_YAML" '.steps[].name' 2>/dev/null | sort -u)"
parallel_step_names="$("$YQ" "$WORKFLOW_YAML" '.steps[].parallel[].name' 2>/dev/null | sort -u || true)"
all_known="$(printf '%s\n%s\nCOMPLETE\nABORT\n' "$defined_steps" "$parallel_step_names" | sort -u | sed '/^$/d')"

all_next_targets=""
for step in plan investigate write_docs review fix; do
    t="$(next_targets_of "$step")"
    all_next_targets="${all_next_targets}${t}"$'\n'
done
invalid=""
while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    if ! grep -qxF "$t" <<<"$all_known"; then
        invalid="${invalid}${t} "
    fi
done <<<"$all_next_targets"
if [[ -z "$invalid" ]]; then
    _record_pass
else
    _record_fail "未知の next 遷移先: $invalid"
fi

print_summary
