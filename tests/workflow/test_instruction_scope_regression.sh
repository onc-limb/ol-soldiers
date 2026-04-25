#!/bin/bash
# tests/workflow/test_instruction_scope_regression.sh
# - Regression guard for QA-NEW-tests-workflow-cross-refs-L95 /
#   TEST-NEW-tests-workflow-test_cross_references-L95.
#
# Why: tests/workflow/test_cross_references.sh が以前 INSTRUCTION_DIR 全体を再帰走査し、
# 他ワークフロー用 instruction（feature-doc 配下の doc-plan / doc-investigate /
# write-user-doc / write-detail-doc / review-doc / fix-doc）の {report:...} 参照を
# 誤って拾って ol-soldiers-style.yaml の生成 report と突合し、6 件 FAIL した退行が
# 起きた。同じパターンの再発を構造的に検出する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

CROSS_REF_TEST="$REPO_ROOT/tests/workflow/test_cross_references.sh"
INSTRUCTION_DIR="$REPO_ROOT/.takt/facets/instructions"

test_start "tests/workflow/test_cross_references.sh が INSTRUCTION_DIR を再帰走査しない"
# Why: `grep -rhoE ... "$INSTRUCTION_DIR"` の再帰走査が再発すると、別ワークフローの
# instruction を巻き込んでしまう。退行パターンを直接検出する。
if grep -qE 'grep -rhoE[^"]*"\$INSTRUCTION_DIR"' "$CROSS_REF_TEST"; then
    _record_fail "再帰走査パターン (grep -rhoE \"...\" \"\$INSTRUCTION_DIR\") が残存している"
else
    _record_pass
fi

test_start "tests/workflow/test_cross_references.sh が宣言済み instruction ID 経由で対象ファイルを限定する"
# Why: スコープ限定の責務はテスト自身に閉じ、宣言済み ID から ${id}.md を構築する形で
# 走査対象を絞る。新規 helper を増やさずパターンが明示される設計。
if grep -qE 'instr_files\+=' "$CROSS_REF_TEST" \
    && grep -qE '\$INSTRUCTION_DIR/\$\{id\}\.md' "$CROSS_REF_TEST"; then
    _record_pass
else
    _record_fail "宣言済み instruction ID から instr_files を構築する箇所が見つからない"
fi

test_start "feature-doc 用 instruction が INSTRUCTION_DIR に共存している（退行が再現可能な前提条件）"
# Why: 退行の前提（feature-doc の instruction が同じディレクトリに存在する）が崩れていない
# ことを確認する。前提が消えるとこの regression test 自体の意味が無くなる。
foreign_instr=(
    "$INSTRUCTION_DIR/doc-plan.md"
    "$INSTRUCTION_DIR/doc-investigate.md"
    "$INSTRUCTION_DIR/write-user-doc.md"
    "$INSTRUCTION_DIR/write-detail-doc.md"
    "$INSTRUCTION_DIR/review-doc.md"
    "$INSTRUCTION_DIR/fix-doc.md"
)
missing=()
for f in "${foreign_instr[@]}"; do
    [[ -f "$f" ]] || missing+=("$f")
done
if (( ${#missing[@]} == 0 )); then
    _record_pass
else
    _record_fail "feature-doc instruction が見当たらない（前提崩れ）: ${missing[*]}"
fi

test_start "tests/workflow/test_cross_references.sh が共存環境でも 0 fail で通過する"
# Why: 構造的検査だけでなく、実走行でも feature-doc instruction を巻き込まないことを確認。
# 実 IO で退行を検出する最終ガード。
output="$(bash "$CROSS_REF_TEST" 2>&1)"
if grep -qE '^  failed: 0$' <<<"$output"; then
    _record_pass
else
    _record_fail "test_cross_references.sh が失敗している（feature-doc instruction を誤検出している可能性）: $(grep -E '^  (passed|failed):' <<<"$output" | tr '\n' ' ')"
fi

print_summary
