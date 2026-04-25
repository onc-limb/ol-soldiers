#!/bin/bash
# tests/feature-doc/test_generic_constraints.sh - feature-doc 汎用性担保の検証
#
# feature-doc は「機能名と出力先ディレクトリを都度指定する」汎用ワークフローなので、
# 以下を禁止する:
# - persona / instruction / workflow 内に具体的な run パス（.takt/runs/...）のハードコード
# - 特定プロジェクト固有のファイルパス・関数名のハードコード
# - 出力先ディレクトリのデフォルト値の埋め込み（都度指定方式のため）
# - WebSearch / WebFetch ツールの有効化（コード調査とドキュメント生成のみで完結する）

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

YQ="$SCRIPT_DIR/../lib/run_yaml_query.sh"
PERSONA_DIR="$REPO_ROOT/.takt/facets/personas"
INSTRUCTION_DIR="$REPO_ROOT/.takt/facets/instructions"
CONTRACT_DIR="$REPO_ROOT/.takt/facets/output-contracts"
WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/feature-doc.yaml"

# 対象 facet 一覧
FEATURE_DOC_PERSONAS=(doc-planner doc-investigator doc-writer doc-reviewer)
FEATURE_DOC_INSTRUCTIONS=(doc-plan doc-investigate write-user-doc write-detail-doc review-doc fix-doc)
FEATURE_DOC_CONTRACTS=(doc-plan doc-investigate doc-write doc-review doc-fix)

# persona / instruction / contract の中に .takt/runs パスや実行時情報を書かない
for name in "${FEATURE_DOC_PERSONAS[@]}"; do
    path="$PERSONA_DIR/${name}.md"
    [[ -f "$path" ]] || continue
    test_start "persona/${name}.md に run ディレクトリパスが書かれていない"
    assert_not_contains "$path" "\\.takt/runs/" ".takt/runs/ パス"
done

for name in "${FEATURE_DOC_INSTRUCTIONS[@]}"; do
    path="$INSTRUCTION_DIR/${name}.md"
    [[ -f "$path" ]] || continue
    test_start "instruction/${name}.md に run ディレクトリパスが書かれていない"
    assert_not_contains "$path" "\\.takt/runs/" ".takt/runs/ パス"
done

# 出力先ディレクトリのデフォルト値を埋め込まない（都度指定要件）
for name in "${FEATURE_DOC_INSTRUCTIONS[@]}"; do
    path="$INSTRUCTION_DIR/${name}.md"
    [[ -f "$path" ]] || continue
    test_start "instruction/${name}.md に特定プロジェクトの絶対パスがハードコードされていない"
    # Why: 出力先ディレクトリは都度指定。/Users/xxx 等を埋め込まない。
    assert_not_contains "$path" "/Users/[a-z]" "/Users/ 始まりの絶対パス"
    assert_not_contains "$path" "/home/[a-z]" "/home/ 始まりの絶対パス"
done

# workflow YAML でも同様
if [[ -f "$WORKFLOW_YAML" ]]; then
    test_start "workflow YAML に run ディレクトリパスがハードコードされていない"
    assert_not_contains "$WORKFLOW_YAML" "\\.takt/runs/" ".takt/runs/"

    test_start "workflow YAML に /Users/ 始まりのハードコード絶対パスがない"
    assert_not_contains "$WORKFLOW_YAML" "/Users/[a-z]" "/Users/ absolute path"
fi

# inbox_write.sh / get_agent_id.sh（ol-soldiers 流儀）を混入させない
for name in "${FEATURE_DOC_PERSONAS[@]}"; do
    path="$PERSONA_DIR/${name}.md"
    [[ -f "$path" ]] || continue
    test_start "persona/${name}.md に ol-soldiers スクリプト参照がない"
    assert_not_contains "$path" "inbox_write\\.sh" "inbox_write.sh"
    assert_not_contains "$path" "get_agent_id\\.sh" "get_agent_id.sh"
done

for name in "${FEATURE_DOC_INSTRUCTIONS[@]}"; do
    path="$INSTRUCTION_DIR/${name}.md"
    [[ -f "$path" ]] || continue
    test_start "instruction/${name}.md に ol-soldiers スクリプト参照がない"
    assert_not_contains "$path" "inbox_write\\.sh" "inbox_write.sh"
    assert_not_contains "$path" "get_agent_id\\.sh" "get_agent_id.sh"
done

# 各 write_* instruction は並列コンフリクト防止のために互いの書き込み先を参照しない
if [[ -f "$INSTRUCTION_DIR/write-user-doc.md" ]]; then
    test_start "write-user-doc.md が detail.md を書き換えないことを明記する（または detail.md に書き込みしない）"
    # Why: 並列書き込み step 同士でファイルコンフリクトしないよう、互いの対象を分離する。
    # detail.md を編集対象として書き換えていないことを担保するため、
    # 「detail.md を編集する」という命令が混入していないかだけを緩くチェック。
    assert_not_contains "$INSTRUCTION_DIR/write-user-doc.md" "detail\\.md を (編集|修正|書き換え|書き込み)" "detail.md を対象にしない"
fi

if [[ -f "$INSTRUCTION_DIR/write-detail-doc.md" ]]; then
    test_start "write-detail-doc.md が user-guide.md を書き換えないことを明記する"
    assert_not_contains "$INSTRUCTION_DIR/write-detail-doc.md" "user-guide\\.md を (編集|修正|書き換え|書き込み)" "user-guide.md を対象にしない"
fi

# network_access を持つ場合でも WebSearch / WebFetch を persona / step に強制しない
# （本ワークフローはコード調査 + ドキュメント生成のみで足りる）
if [[ -f "$WORKFLOW_YAML" ]]; then
    test_start "workflow YAML の plan step に WebSearch / WebFetch が含まれていない"
    # Why: plan ステップはコードベース内を Grep / Glob で探すだけ。ネットワーク不要。
    plan_tools="$("$YQ" "$WORKFLOW_YAML" '.steps[] | select(.name == "plan") | .provider_options.claude.allowed_tools' 2>/dev/null || true)"
    if grep -q 'WebSearch\|WebFetch' <<<"$plan_tools"; then
        _record_fail "plan step に WebSearch / WebFetch が含まれている（本ワークフローでは不要）"
    else
        _record_pass
    fi

    test_start "workflow YAML の investigate step に WebSearch / WebFetch が含まれていない"
    investigate_tools="$("$YQ" "$WORKFLOW_YAML" '.steps[] | select(.name == "investigate") | .provider_options.claude.allowed_tools' 2>/dev/null || true)"
    if grep -q 'WebSearch\|WebFetch' <<<"$investigate_tools"; then
        _record_fail "investigate step に WebSearch / WebFetch が含まれている（本ワークフローでは不要）"
    else
        _record_pass
    fi
fi

print_summary
