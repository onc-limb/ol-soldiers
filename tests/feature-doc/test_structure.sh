#!/bin/bash
# tests/feature-doc/test_structure.sh - feature-doc ワークフローの配置とファイル存在の検証
#
# 計画レポート (.takt/runs/.../reports/plan.md) で列挙された feature-doc ワークフロー
# 関連ファイル（ワークフロー YAML + persona 4 / instruction 6 / output-contract 5）が
# 既存 .takt/facets/ / .takt/workflows/ のレイアウトに沿って正しく配置されていること、
# および takt doctor が構造診断で通ることを確認する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/feature-doc.yaml"
PERSONA_DIR="$REPO_ROOT/.takt/facets/personas"
INSTRUCTION_DIR="$REPO_ROOT/.takt/facets/instructions"
CONTRACT_DIR="$REPO_ROOT/.takt/facets/output-contracts"

test_start "feature-doc ワークフロー YAML が配置されている"
assert_file_exists "$WORKFLOW_YAML"

test_start "4 種類の persona ファイルが配置されている"
# Why: plan で列挙された doc-planner / doc-investigator / doc-writer / doc-reviewer。
# write_user_doc / write_detail_doc / fix の 3 ステップは doc-writer ペルソナを共有する。
for name in doc-planner doc-investigator doc-writer doc-reviewer; do
    assert_file_exists "$PERSONA_DIR/${name}.md"
done

test_start "各 step の instruction ファイルが配置されている"
# Why: plan / investigate / write_user_doc / write_detail_doc / review / fix の 6 instruction。
for name in \
    doc-plan \
    doc-investigate \
    write-user-doc \
    write-detail-doc \
    review-doc \
    fix-doc; do
    assert_file_exists "$INSTRUCTION_DIR/${name}.md"
done

test_start "各 step の output-contract ファイルが配置されている"
# Why: plan / investigate / write (共通) / review / fix の 5 契約。
# doc-write は write_user_doc / write_detail_doc で共有する。
for name in \
    doc-plan \
    doc-investigate \
    doc-write \
    doc-review \
    doc-fix; do
    assert_file_exists "$CONTRACT_DIR/${name}.md"
done

test_start "takt workflow doctor が構造診断エラーを出さない"
# Why: doctor は参照解決・遷移グラフ妥当性・スキーマ妥当性を一括検証する
# takt 標準の検証機構。これに通らない状態は実装バグ。
TAKT_BIN="/opt/homebrew/lib/node_modules/takt/bin/takt"
if [[ ! -x "$TAKT_BIN" ]]; then
    _record_fail "takt CLI not executable at: $TAKT_BIN"
else
    if (cd "$REPO_ROOT" && "$TAKT_BIN" workflow doctor feature-doc) >/dev/null 2>&1; then
        _record_pass
    else
        _record_fail "takt workflow doctor feature-doc が失敗した"
    fi
fi

print_summary
