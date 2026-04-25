#!/bin/bash
# tests/workflow/test_structure.sh - ワークフロー配置とファイル存在の検証
#
# 計画レポート (.takt/runs/.../reports/plan.md) が列挙した 25 以上のファイルが
# 正しいパスに配置されていること、および takt 標準の doctor が構造診断で
# エラーを出さないことを確認する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

WORKFLOW_YAML="$REPO_ROOT/.takt/workflows/ol-soldiers-style.yaml"
PERSONA_DIR="$REPO_ROOT/.takt/facets/personas"
INSTRUCTION_DIR="$REPO_ROOT/.takt/facets/instructions"
CONTRACT_DIR="$REPO_ROOT/.takt/facets/output-contracts"

test_start "ワークフロー YAML が配置されている"
assert_file_exists "$WORKFLOW_YAML"

test_start "6 種類の persona ファイルが配置されている"
for name in commander sergeant soldier task-inspector goal-inspector facilitator; do
    assert_file_exists "$PERSONA_DIR/${name}.md"
done

test_start "Facilitator + 各 phase の instruction ファイルが配置されている"
# Why: 計画で挙げられた全 instruction。cycle-summary / escalate-summary は
# phase step 名ではなく report 生成用の持ち回り instruction として扱う。
for name in \
    intake \
    plan-split \
    execute-team-leader \
    task-review \
    completion-check \
    goal-review \
    cycle-summary \
    escalate-summary \
    loop-monitor-cycle; do
    assert_file_exists "$INSTRUCTION_DIR/${name}.md"
done

test_start "各 step の output-contract ファイルが配置されている"
for name in \
    intake \
    plan-split \
    execute \
    task-review \
    completion-check \
    goal-review \
    cycle-summary \
    escalate-summary; do
    assert_file_exists "$CONTRACT_DIR/${name}.md"
done

test_start "takt workflow doctor が構造診断エラーを出さない"
# Why: doctor は参照解決・遷移グラフ妥当性・スキーマ妥当性を一括検証する
# takt 標準の検証機構。これに通らない状態は実装バグ。
TAKT_BIN="/opt/homebrew/lib/node_modules/takt/bin/takt"
if [[ ! -x "$TAKT_BIN" ]]; then
    _record_fail "takt CLI not executable at: $TAKT_BIN"
else
    # doctor はプロジェクトディレクトリ内で実行する必要がある
    if (cd "$REPO_ROOT" && "$TAKT_BIN" workflow doctor ol-soldiers-style) >/dev/null 2>&1; then
        _record_pass
    else
        _record_fail "takt workflow doctor ol-soldiers-style が失敗した"
    fi
fi

print_summary
