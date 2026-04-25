#!/bin/bash
# tests/feature-doc/test_cross_references.sh - feature-doc 内参照の整合性検証
#
# feature-doc.yaml が参照する persona / instruction / output-contract 名が
# すべて実ファイルに対応していること、および instruction 内の {report:xxx.md}
# 参照が workflow 上で先行 step によって生成されるかを確認する。
#
# parallel 配下のサブステップも含めて走査する（既存 ol-soldiers-style.yaml には
# parallel ブロックがないため、takt-default.yaml 相当の仕様を踏まえる）。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

YQ="$SCRIPT_DIR/../lib/run_yaml_query.sh"
WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/feature-doc.yaml"
PERSONA_DIR="$REPO_ROOT/.takt/facets/personas"
INSTRUCTION_DIR="$REPO_ROOT/.takt/facets/instructions"
CONTRACT_DIR="$REPO_ROOT/.takt/facets/output-contracts"

if [[ ! -f "$WORKFLOW_YAML" ]]; then
    echo "  (skip) feature-doc workflow YAML not yet created"
    print_summary
    exit $?
fi

test_start "workflow 内で参照される全 persona にファイルが存在する"
top_personas="$("$YQ" "$WORKFLOW_YAML" '.steps[].persona' 2>/dev/null | sort -u || true)"
parallel_personas="$("$YQ" "$WORKFLOW_YAML" '.steps[].parallel[].persona' 2>/dev/null | sort -u || true)"
monitor_personas="$("$YQ" "$WORKFLOW_YAML" '.loop_monitors[].judge.persona' 2>/dev/null | sort -u || true)"
all_personas="$(printf '%s\n%s\n%s\n' "$top_personas" "$parallel_personas" "$monitor_personas" | sort -u | sed '/^$/d')"
if [[ -z "$all_personas" ]]; then
    _record_fail "workflow に persona 参照が見つからなかった"
else
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        if [[ -f "$PERSONA_DIR/${p}.md" ]]; then
            _record_pass
        else
            _record_fail "persona ファイルが存在しない: $p (expected $PERSONA_DIR/${p}.md)"
        fi
    done <<<"$all_personas"
fi

test_start "workflow 内で参照される全 instruction にファイルが存在する"
top_instr="$("$YQ" "$WORKFLOW_YAML" '.steps[].instruction' 2>/dev/null | sort -u || true)"
parallel_instr="$("$YQ" "$WORKFLOW_YAML" '.steps[].parallel[].instruction' 2>/dev/null | sort -u || true)"
all_instr="$(printf '%s\n%s\n' "$top_instr" "$parallel_instr" | sort -u | sed '/^$/d')"
if [[ -z "$all_instr" ]]; then
    _record_fail "workflow に instruction 参照が見つからなかった"
else
    while IFS= read -r i; do
        [[ -z "$i" ]] && continue
        # instruction はインラインテキストのこともあるので ID 形式（英字/ハイフンのみ）だけ検証
        if [[ "$i" =~ ^[a-z][a-z0-9-]*$ ]]; then
            if [[ -f "$INSTRUCTION_DIR/${i}.md" ]]; then
                _record_pass
            else
                _record_fail "instruction ファイルが存在しない: $i (expected $INSTRUCTION_DIR/${i}.md)"
            fi
        fi
    done <<<"$all_instr"
fi

test_start "workflow 内で参照される全 output-contract format にファイルが存在する"
top_contracts="$("$YQ" "$WORKFLOW_YAML" '.steps[].output_contracts.report[].format' 2>/dev/null | sort -u || true)"
parallel_contracts="$("$YQ" "$WORKFLOW_YAML" '.steps[].parallel[].output_contracts.report[].format' 2>/dev/null | sort -u || true)"
all_contracts="$(printf '%s\n%s\n' "$top_contracts" "$parallel_contracts" | sort -u | sed '/^$/d')"
if [[ -z "$all_contracts" ]]; then
    _record_fail "workflow に output_contracts 参照が見つからなかった"
else
    while IFS= read -r c; do
        [[ -z "$c" ]] && continue
        if [[ -f "$CONTRACT_DIR/${c}.md" ]]; then
            _record_pass
        else
            _record_fail "output-contract ファイルが存在しない: $c (expected $CONTRACT_DIR/${c}.md)"
        fi
    done <<<"$all_contracts"
fi

test_start "feature-doc 用 instruction 内の {report:*.md} 参照先が workflow 上で生成される"
# Why: 存在しない report を参照すると engine が空文字列を埋め込み、指示が崩れる。
#      feature-doc の 6 instruction のみを対象にチェックする（他ワークフローの
#      instruction に混じった参照をここで拾わないように限定する）。
top_reports="$("$YQ" "$WORKFLOW_YAML" '.steps[].output_contracts.report[].name' 2>/dev/null | sort -u || true)"
parallel_reports="$("$YQ" "$WORKFLOW_YAML" '.steps[].parallel[].output_contracts.report[].name' 2>/dev/null | sort -u || true)"
report_names_generated="$(printf '%s\n%s\n' "$top_reports" "$parallel_reports" | sort -u | sed '/^$/d')"
if [[ -z "$report_names_generated" ]]; then
    _record_fail "workflow が一つも report を生成していない"
else
    feature_doc_instructions=(
        "$INSTRUCTION_DIR/doc-plan.md"
        "$INSTRUCTION_DIR/doc-investigate.md"
        "$INSTRUCTION_DIR/write-user-doc.md"
        "$INSTRUCTION_DIR/write-detail-doc.md"
        "$INSTRUCTION_DIR/review-doc.md"
        "$INSTRUCTION_DIR/fix-doc.md"
    )
    existing=()
    for f in "${feature_doc_instructions[@]}"; do
        [[ -f "$f" ]] && existing+=("$f")
    done
    if (( ${#existing[@]} == 0 )); then
        echo "    (skip) feature-doc instruction files not yet created"
    else
        referenced="$(grep -hoE '\{report:[^}]+\}' "${existing[@]}" 2>/dev/null \
            | sed -E 's/\{report:([^}]+)\}/\1/' | sort -u)"
        if [[ -z "$referenced" ]]; then
            # 参照がない場合は意図的に持たないケース
            _record_pass
        else
            while IFS= read -r name; do
                [[ -z "$name" ]] && continue
                if grep -qxF "$name" <<<"$report_names_generated"; then
                    _record_pass
                else
                    _record_fail "feature-doc instruction が参照する report '$name' が workflow のどの step でも生成されない"
                fi
            done <<<"$referenced"
        fi
    fi
fi

print_summary
