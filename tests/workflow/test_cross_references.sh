#!/bin/bash
# tests/workflow/test_cross_references.sh - ワークフロー内参照の整合性検証
#
# workflow.yaml が参照する persona / instruction / output-contract 名が
# すべて実ファイルに対応していることを確認する。
# また、instruction 内の {report:xxx.md} 参照が workflow.yaml 上で
# 先行 step によって生成されるかも確認する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

YQ="$SCRIPT_DIR/../lib/run_yaml_query.sh"
WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/ol-soldiers-style.yaml"
PERSONA_DIR="$REPO_ROOT/.takt/facets/personas"
INSTRUCTION_DIR="$REPO_ROOT/.takt/facets/instructions"
CONTRACT_DIR="$REPO_ROOT/.takt/facets/output-contracts"

if [[ ! -f "$WORKFLOW_YAML" ]]; then
    echo "  (skip) workflow YAML not yet created"
    print_summary
    exit $?
fi

test_start "workflow 内で参照される全 persona にファイルが存在する"
personas="$("$YQ" "$WORKFLOW_YAML" '.steps[].persona' 2>/dev/null | sort -u)"
# team_leader 配下の persona も集める
tl_persona="$("$YQ" "$WORKFLOW_YAML" '.steps[].team_leader.persona' 2>/dev/null | sort -u || true)"
tl_part="$("$YQ" "$WORKFLOW_YAML" '.steps[].team_leader.part_persona' 2>/dev/null | sort -u || true)"
monitor_persona="$("$YQ" "$WORKFLOW_YAML" '.loop_monitors[].judge.persona' 2>/dev/null | sort -u || true)"
all_personas="$(printf '%s\n%s\n%s\n%s\n' "$personas" "$tl_persona" "$tl_part" "$monitor_persona" | sort -u | sed '/^$/d')"
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
instructions="$("$YQ" "$WORKFLOW_YAML" '.steps[].instruction' 2>/dev/null | sort -u)"
monitor_instr="$("$YQ" "$WORKFLOW_YAML" '.loop_monitors[].judge.instruction' 2>/dev/null | sort -u || true)"
all_instructions="$(printf '%s\n%s\n' "$instructions" "$monitor_instr" | sort -u | sed '/^$/d')"
if [[ -z "$all_instructions" ]]; then
    _record_fail "workflow に instruction 参照が見つからなかった"
else
    while IFS= read -r i; do
        [[ -z "$i" ]] && continue
        # instruction はインラインテキストのこともあるので ID 形式 (英字/ハイフンのみ) だけ検証
        if [[ "$i" =~ ^[a-z][a-z0-9-]*$ ]]; then
            if [[ -f "$INSTRUCTION_DIR/${i}.md" ]]; then
                _record_pass
            else
                _record_fail "instruction ファイルが存在しない: $i (expected $INSTRUCTION_DIR/${i}.md)"
            fi
        fi
    done <<<"$all_instructions"
fi

test_start "workflow 内で参照される全 output-contract format にファイルが存在する"
contracts="$("$YQ" "$WORKFLOW_YAML" '.steps[].output_contracts.report[].format' 2>/dev/null | sort -u)"
if [[ -z "$contracts" ]]; then
    _record_fail "workflow に output_contracts 参照が見つからなかった"
else
    while IFS= read -r c; do
        [[ -z "$c" ]] && continue
        if [[ -f "$CONTRACT_DIR/${c}.md" ]]; then
            _record_pass
        else
            _record_fail "output-contract ファイルが存在しない: $c (expected $CONTRACT_DIR/${c}.md)"
        fi
    done <<<"$contracts"
fi

test_start "instruction 内の {report:*.md} 参照先が workflow 上で先行 step によって生成される"
# Why: 存在しない report を参照すると engine が空文字列を埋め込み、指示が崩れる。
# instruction ごとに「使う step 名」の対応が取りにくいので、全 instruction を横断して
# 参照されるすべての report 名が、workflow 全体のどこかで生成されているかをチェックする。
report_names_generated="$("$YQ" "$WORKFLOW_YAML" '.steps[].output_contracts.report[].name' 2>/dev/null | sort -u)"
if [[ -z "$report_names_generated" ]]; then
    _record_fail "workflow が一つも report を生成していない"
else
    # Instruction ディレクトリから {report:xxx.md} を抽出
    if [[ -d "$INSTRUCTION_DIR" ]]; then
        # grep -h: ファイル名抑制、-o: マッチ部分のみ
        referenced="$(grep -rhoE '\{report:[^}]+\}' "$INSTRUCTION_DIR" 2>/dev/null \
            | sed -E 's/\{report:([^}]+)\}/\1/' | sort -u)"
        if [[ -z "$referenced" ]]; then
            # 参照がなくても OK (まだ実装前 / 意図的に持たない)
            _record_pass
        else
            while IFS= read -r name; do
                [[ -z "$name" ]] && continue
                if grep -qxF "$name" <<<"$report_names_generated"; then
                    _record_pass
                else
                    _record_fail "instruction が参照する report '$name' が workflow のどの step でも生成されない"
                fi
            done <<<"$referenced"
        fi
    fi
fi

print_summary
