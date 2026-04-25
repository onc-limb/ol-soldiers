#!/bin/bash
# tests/workflow/test_generic_constraints.sh - 汎用性担保の検証
#
# 「特定プロジェクトに依存しない汎用構成」が要件。以下が禁止:
# - persona / instruction / workflow 内に具体的な run パス (.takt/runs/...) をハードコード
# - テスト実行コマンド (npm test / pytest / cargo test) を workflow / persona / instruction に固定記述
# - 特定プロジェクトの言語・フレームワーク名を前提とする文言

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

PERSONA_DIR="$REPO_ROOT/.takt/facets/personas"
INSTRUCTION_DIR="$REPO_ROOT/.takt/facets/instructions"
CONTRACT_DIR="$REPO_ROOT/.takt/facets/output-contracts"
WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/ol-soldiers-style.yaml"

# persona に具体パスを書かない
for name in commander sergeant soldier task-inspector goal-inspector facilitator; do
    path="$PERSONA_DIR/${name}.md"
    test_start "persona/${name}.md に run ディレクトリパスが書かれていない"
    assert_not_contains "$path" "\\.takt/runs/" ".takt/runs/ パス"
done

# persona にテストコマンドがハードコードされていない (goal-inspector 以外)
# goal-inspector は「package.json 等から動的特定」と書くので特定ワード自体は出現する
# ただし npm test / pytest / cargo test のような具体コマンドを instruction 命令として
# 書かないこと。ここではコマンド文字列がコードブロック内に単独で出現するケースを
# 防ぐ弱めのチェックに留める。
for name in commander sergeant soldier task-inspector facilitator; do
    path="$PERSONA_DIR/${name}.md"
    test_start "persona/${name}.md に特定テストランナーのコマンドがハードコードされていない"
    assert_not_contains "$path" "npm (run )?test\\b" "npm test"
    assert_not_contains "$path" "\\bpytest\\b" "pytest"
    assert_not_contains "$path" "cargo test\\b" "cargo test"
    assert_not_contains "$path" "go test\\b" "go test"
done

# workflow YAML 内にも同様のハードコードは禁止
if [[ -f "$WORKFLOW_YAML" ]]; then
    test_start "workflow YAML にテストコマンドが直接書かれていない"
    assert_not_contains "$WORKFLOW_YAML" "npm (run )?test\\b" "npm test"
    assert_not_contains "$WORKFLOW_YAML" "\\bpytest\\b" "pytest"
    assert_not_contains "$WORKFLOW_YAML" "cargo test\\b" "cargo test"
    assert_not_contains "$WORKFLOW_YAML" "go test\\b" "go test"
fi

# workflow YAML に ol-soldiers 固有の inbox_write.sh 参照が混入していない
# Why: ol-soldiers の通信スクリプトを移植しないという明示要件。
if [[ -f "$WORKFLOW_YAML" ]]; then
    test_start "workflow YAML に inbox_write.sh / get_agent_id.sh 参照がない"
    assert_not_contains "$WORKFLOW_YAML" "inbox_write\\.sh" "inbox_write.sh"
    assert_not_contains "$WORKFLOW_YAML" "get_agent_id\\.sh" "get_agent_id.sh"
fi

# instruction にも同様
for f in "$INSTRUCTION_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    test_start "instruction/${name} に inbox_write.sh / get_agent_id.sh 参照がない"
    assert_not_contains "$f" "inbox_write\\.sh" "inbox_write.sh"
    assert_not_contains "$f" "get_agent_id\\.sh" "get_agent_id.sh"
done

# persona にも同様 (思想は参考にしつつ takt 流儀に翻案する要件)
for name in commander sergeant soldier task-inspector goal-inspector facilitator; do
    path="$PERSONA_DIR/${name}.md"
    test_start "persona/${name}.md に inbox_write.sh / get_agent_id.sh 参照がない"
    assert_not_contains "$path" "inbox_write\\.sh" "inbox_write.sh"
    assert_not_contains "$path" "get_agent_id\\.sh" "get_agent_id.sh"
done

# persona に「具体的な step 名」がハードコードされていないことを緩やかにチェック
# Why: workflow ルーティングは workflow.yaml の責務。persona は責務ベースで書く。
# ただし persona がその役割の文脈で許容される step 名 (例: soldier が execute を知る) は許容する。
# ここでは「全 persona 共通で現れるべきでない step 名」のみ厳格チェック。
for name in commander sergeant; do
    path="$PERSONA_DIR/${name}.md"
    test_start "persona/${name}.md が workflow 内部の escalation step 名を直接参照していない"
    # escalate_info_gap / escalate_blocked / escalate_cycle_limit は workflow.yaml 固有名称
    assert_not_contains "$path" "escalate_info_gap\\b" "escalate_info_gap 直参照"
    assert_not_contains "$path" "escalate_blocked\\b" "escalate_blocked 直参照"
    assert_not_contains "$path" "escalate_cycle_limit\\b" "escalate_cycle_limit 直参照"
done

print_summary
