#!/bin/bash
# tests/feature-doc/test_personas.sh - feature-doc persona ファイルの役割境界・行動原則の検証
#
# 計画レポートで各 persona に求めた「役割の境界」「行動姿勢」「編集スコープ」等が
# persona ファイルに明記されているかを検証する。ペルソナはドメイン知識と行動原則のみ
# を持ち、ワークフロー固有の step 名や手順はインストラクションに書く（engine.md 参照）。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

PERSONA_DIR="$REPO_ROOT/.takt/facets/personas"

# 4 種類 persona 全員に共通で要求される項目
for name in doc-planner doc-investigator doc-writer doc-reviewer; do
    path="$PERSONA_DIR/${name}.md"
    test_start "persona/${name}.md に役割セクションがある（やること／やらないこと）"
    # Why: 既存 persona と同じ「役割の境界」構造に揃える。
    assert_contains "$path" "やること|役割" "やること / 役割"
    assert_contains "$path" "やらないこと|禁止" "やらないこと / 禁止"

    test_start "persona/${name}.md に行動姿勢セクションがある"
    assert_contains "$path" "行動姿勢|姿勢" "行動姿勢"
done

# doc-planner 固有
planner="$PERSONA_DIR/doc-planner.md"
test_start "doc-planner.md が機能名と出力先ディレクトリの抽出責務を明記する"
assert_contains "$planner" "機能名" "機能名抽出"
assert_contains "$planner" "出力先|出力 ?ディレクトリ" "出力先ディレクトリ抽出"

test_start "doc-planner.md がコード変更 / ドキュメント執筆を禁止している"
# Why: plan ステップは edit: false。ペルソナ側も非編集の原則を明記する。
assert_contains "$planner" "コード.*変更しない|コード.*禁止|編集しない|Edit.*禁止" "コード変更禁止"
assert_contains "$planner" "執筆しない|本文.*書かない|本文.*禁止" "本文執筆禁止"

test_start "doc-planner.md が調査スコープと章立て設計の責務を明記する"
assert_contains "$planner" "スコープ|対象ファイル|範囲" "スコープ設計"
assert_contains "$planner" "章立て|章構成|構成" "章立て設計"

# doc-investigator 固有
inv="$PERSONA_DIR/doc-investigator.md"
test_start "doc-investigator.md が事実ベースの構造化抽出責務を明記する"
# Why: plan の「構造化された中間レポートを事実ベースで」（要件 25）。
assert_contains "$inv" "事実|ファクト" "事実ベース"
assert_contains "$inv" "構造化|構造" "構造化抽出"

test_start "doc-investigator.md が起動経路（ユーザー到達経路）の追跡を含む"
# Why: plan 2-2「起動経路（ユーザーがこの機能に到達する経路）」の明示。
assert_contains "$inv" "起動経路|到達経路|入口|エントリ" "起動経路追跡"

test_start "doc-investigator.md が本文執筆・コード変更を禁止している"
assert_contains "$inv" "執筆しない|本文.*書かない|本文.*禁止|ドキュメント.*書かない" "ドキュメント執筆禁止"
assert_contains "$inv" "コード.*変更しない|Edit.*禁止|編集しない" "コード変更禁止"

test_start "doc-investigator.md が未確認事項を明記する原則を示している"
# Why: 「推測の振る舞いを断定で書かない（不明は未確認と明記）」
assert_contains "$inv" "未確認|推測しない|断定しない" "未確認事項の明記"

# doc-writer 固有
writer="$PERSONA_DIR/doc-writer.md"
test_start "doc-writer.md が日本語 Markdown での出力を宣言している"
# Why: 要件 13 / 14「言語: 日本語、形式: Markdown」。
assert_contains "$writer" "日本語" "日本語出力"
assert_contains "$writer" "Markdown|マークダウン" "Markdown 形式"

test_start "doc-writer.md が中間レポートにない事実を捏造しない原則を明記する"
# Why: 「中間レポートに無い事実を捏造しない」が行動原則。
assert_contains "$writer" "捏造しない|根拠のない|中間レポート.*限る|ない事実" "事実捏造禁止"

test_start "doc-writer.md が編集スコープを指定 1 ファイルに限定している"
# Why: write_user_doc / write_detail_doc / fix の 3 ステップで共有するため、
# 「対象ファイル以外を書き換えない」原則をペルソナで明示する。
assert_contains "$writer" "対象ファイル以外.*書き換えない|スコープ外.*編集しない|指定.*以外.*編集しない|1 ?ファイル" "編集スコープ限定"

test_start "doc-writer.md が Mermaid 図を実装と整合させる原則を明記する"
# Why: 「Mermaid 図は必ず実装と整合させる」が共通行動原則（detail.md 側の責務）。
assert_contains "$writer" "Mermaid" "Mermaid 整合"
assert_contains "$writer" "整合|一致|実装.*合わせる|実装.*揃える" "実装整合"

# doc-reviewer 固有
reviewer="$PERSONA_DIR/doc-reviewer.md"
test_start "doc-reviewer.md が観点優先順位「読みやすさ → 正確性」を明記する"
# Why: 要件 24。観点順は reviewer の核。
assert_contains "$reviewer" "読みやすさ" "読みやすさ"
assert_contains "$reviewer" "正確性" "正確性"

test_start "doc-reviewer.md が本体編集を禁止している"
# Why: 要件 22。review は指摘のみ、本体は編集不可。
assert_contains "$reviewer" "編集しない|修正しない|本体.*禁止|Edit.*禁止" "本体編集禁止"

test_start "doc-reviewer.md が指摘対象の具体箇所明示を求める"
# Why: 「指摘は具体的な該当箇所（ファイル:行 or 章節）と修正方向を併記」。
assert_contains "$reviewer" "該当箇所|章節|ファイル:|行番号|具体的" "具体的な指摘箇所"

test_start "doc-reviewer.md が Mermaid 図と実装の一致確認を含む"
assert_contains "$reviewer" "Mermaid" "Mermaid 一致確認"

print_summary
