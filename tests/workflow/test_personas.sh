#!/bin/bash
# tests/workflow/test_personas.sh - persona ファイルのコンテキスト境界と役割境界の検証
#
# 計画レポートで指定された「受け取るコンテキスト / 出力するコンテキスト」や
# 3 層防御思想の反映、/clear 禁止、AND 判定などをファイル内容で確認する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

PERSONA_DIR="$REPO_ROOT/.takt/facets/personas"

# すべての persona に共通で要求される項目
for name in commander sergeant soldier task-inspector goal-inspector facilitator; do
    path="$PERSONA_DIR/${name}.md"
    test_start "persona/${name}.md に受け取る/出力するコンテキストが明記されている"
    assert_contains "$path" "受け取るコンテキスト" "受け取るコンテキスト セクション"
    assert_contains "$path" "出力するコンテキスト" "出力するコンテキスト セクション"

    test_start "persona/${name}.md に やらないこと が明記されている"
    assert_contains "$path" "やらないこと|禁止" "やらないこと セクション"

    test_start "persona/${name}.md が /clear 相当を禁止している"
    # Why: 「エージェントに /clear 相当をさせない前提で設計する」が全 persona 共通要件。
    assert_contains "$path" "/clear|セッションリセット|session.*refresh" "セッションリセット禁止の記述"
done

# commander 固有の要件
test_start "commander.md が情報不足検知時のエスカレーションに言及している"
assert_contains "$PERSONA_DIR/commander.md" "情報不足|ヒアリング|escalate|質問" "情報不足エスカレーション"

test_start "commander.md が自分では実装しないことを明記している"
# Why: Commander 思想「自分では一切実装しない」(ol-soldiers の根幹設計) を担保。
assert_contains "$PERSONA_DIR/commander.md" "実装しない|Edit.*禁止|コード.*書かない|Edit/Write.*禁止" "自分で実装しない原則"

# sergeant 固有
test_start "sergeant.md が 1 タスク 1 機能 1 関心事を指示している"
assert_contains "$PERSONA_DIR/sergeant.md" "1 ?機能|1 ?関心事|単一.*責務|1 ?task|1 ?タスク" "1 タスク 1 機能 1 関心事"

test_start "sergeant.md が関連ファイルリストの必須性に言及している"
assert_contains "$PERSONA_DIR/sergeant.md" "関連ファイル|対象ファイル|target_path|related" "関連ファイル必須"

test_start "sergeant.md が依存関係・並列可否の明示に言及している"
assert_contains "$PERSONA_DIR/sergeant.md" "依存|dependencies|並列|parallel" "依存・並列可否"

# soldier 固有
test_start "soldier.md が単一タスクへの集中を指示している"
assert_contains "$PERSONA_DIR/soldier.md" "単一|一つ|one task|1 ?タスク" "単一タスク集中"

test_start "soldier.md が受信コンテキストをタスク範囲に限定している"
assert_contains "$PERSONA_DIR/soldier.md" "タスク定義|関連ファイル|前提情報" "限定的なコンテキスト受信"

test_start "soldier.md がスコープ外書き込みを禁止している"
# Why: ol-soldiers の target_path 外書き込み禁止を takt 流儀に翻案。
assert_contains "$PERSONA_DIR/soldier.md" "スコープ外|範囲外|担当外|target_path 外|担当ファイル以外" "スコープ外書き込み禁止"

# task-inspector 固有
test_start "task-inspector.md が approved / needs_revision / rejected の 3 値判定を宣言する"
assert_contains "$PERSONA_DIR/task-inspector.md" "approved" "approved"
assert_contains "$PERSONA_DIR/task-inspector.md" "needs_revision" "needs_revision"
assert_contains "$PERSONA_DIR/task-inspector.md" "rejected" "rejected"

test_start "task-inspector.md が実装者と独立する必要性を明記している"
assert_contains "$PERSONA_DIR/task-inspector.md" "独立|実装者|評価者|編集しない|edit.*false" "実装者との独立性"

# goal-inspector 固有
test_start "goal-inspector.md が approved / needs_more_cycles / blocked の 3 値を宣言する"
assert_contains "$PERSONA_DIR/goal-inspector.md" "approved" "approved"
assert_contains "$PERSONA_DIR/goal-inspector.md" "needs_more_cycles" "needs_more_cycles"
assert_contains "$PERSONA_DIR/goal-inspector.md" "blocked" "blocked"

test_start "goal-inspector.md が AND 判定 (目的達成 かつ テスト通過) を明記している"
# Why: 「目的達成 AND テスト通過」の AND 判定は Goal Inspector の核。
assert_contains "$PERSONA_DIR/goal-inspector.md" "かつ|AND|両方" "AND 条件"
assert_contains "$PERSONA_DIR/goal-inspector.md" "テスト.*通過|テスト.*成功|tests?.*pass" "テスト通過判定"

test_start "goal-inspector.md がテストコマンドを動的に特定する手順を記述している"
# Why: 特定コマンドをハードコードしない要件。package.json 等から動的に取る。
assert_contains "$PERSONA_DIR/goal-inspector.md" "package\.json|pyproject\.toml|Cargo\.toml|Makefile" "テストコマンド動的特定"

test_start "goal-inspector.md がテスト未通過時は approved を返さないと明記している"
assert_contains "$PERSONA_DIR/goal-inspector.md" "テスト.*未|テスト.*失敗|通過.*確認" "テスト未通過時の扱い"

# facilitator 固有
test_start "facilitator.md がサイクル間の要約圧縮責務を明記している"
assert_contains "$PERSONA_DIR/facilitator.md" "要約|サマリ|summary|圧縮" "要約圧縮"

test_start "facilitator.md がサイクル跨ぎの保持情報 (目的・達成状況・決定事項・未解決課題・成果物ポインタ) を列挙している"
path="$PERSONA_DIR/facilitator.md"
assert_contains "$path" "目的" "目的"
assert_contains "$path" "達成状況|達成条件" "達成状況"
assert_contains "$path" "決定事項" "決定事項"
assert_contains "$path" "未解決|残課題|open.*issue" "未解決課題"
assert_contains "$path" "成果物|ポインタ|pointer" "成果物ポインタ"

print_summary
