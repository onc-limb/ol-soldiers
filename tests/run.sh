#!/bin/bash
# tests/run.sh - ol-soldiers-style ワークフローのテスト実行エントリポイント
#
# 使い方: bash tests/run.sh
# または 個別実行: bash tests/workflow/test_structure.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITES=(
    "$SCRIPT_DIR/workflow/test_structure.sh"
    "$SCRIPT_DIR/workflow/test_workflow_yaml.sh"
    "$SCRIPT_DIR/workflow/test_personas.sh"
    "$SCRIPT_DIR/workflow/test_instructions.sh"
    "$SCRIPT_DIR/workflow/test_output_contracts.sh"
    "$SCRIPT_DIR/workflow/test_cross_references.sh"
    "$SCRIPT_DIR/workflow/test_generic_constraints.sh"
    "$SCRIPT_DIR/workflow/test_integration_flow.sh"
    "$SCRIPT_DIR/workflow/test_instruction_scope_regression.sh"
    "$SCRIPT_DIR/feature-doc/test_structure.sh"
    "$SCRIPT_DIR/feature-doc/test_workflow_yaml.sh"
    "$SCRIPT_DIR/feature-doc/test_personas.sh"
    "$SCRIPT_DIR/feature-doc/test_instructions.sh"
    "$SCRIPT_DIR/feature-doc/test_output_contracts.sh"
    "$SCRIPT_DIR/feature-doc/test_cross_references.sh"
    "$SCRIPT_DIR/feature-doc/test_generic_constraints.sh"
    "$SCRIPT_DIR/feature-doc/test_integration_flow.sh"
)

total_pass=0
total_fail=0
failed_suites=()

for suite in "${SUITES[@]}"; do
    # Why: workflow/ と feature-doc/ で同名ファイルが併存するため、親ディレクトリを含めて
    # 表示名にする。basename だけでは FAILED SUITES 一覧で衝突して区別がつかない。
    name="$(basename "$(dirname "$suite")")/$(basename "$suite")"
    printf '\n=== %s ===\n' "$name"
    if bash "$suite"; then
        # suite 内 print_summary が exit 0 を返す → 全 pass
        :
    else
        failed_suites+=("$name")
    fi
    # pass / fail 数は各 suite のサマリから集計する (現状は終了コードのみで判定)
done

printf '\n======================================================\n'
if (( ${#failed_suites[@]} == 0 )); then
    printf '  ALL SUITES PASSED\n'
    printf '======================================================\n'
    exit 0
fi

printf '  FAILED SUITES:\n'
for s in "${failed_suites[@]}"; do
    printf '    - %s\n' "$s"
done
printf '======================================================\n'
exit 1
