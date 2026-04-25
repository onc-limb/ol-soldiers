#!/bin/bash
# tests/feature-doc/test_instructions.sh - feature-doc instruction ファイルの仕様検証
#
# 各 instruction に計画レポートが求めた振る舞い（入力参照 / 出力先 / 必須セクション /
# 言語・形式 / Mermaid 必須 / 読者想定 / 禁止事項）がテキストに反映されているかを検証する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

INSTRUCTION_DIR="$REPO_ROOT/.takt/facets/instructions"

# doc-plan: 機能名 / 出力先抽出 + 章立て設計
plan="$INSTRUCTION_DIR/doc-plan.md"
test_start "doc-plan.md が {task} から機能名と出力先ディレクトリを抽出する手順を含む"
# Why: ユーザー入力から plan が抽出する（計画の到達経路・起動条件）。
assert_contains "$plan" "機能名" "機能名"
assert_contains "$plan" "出力先|出力 ?ディレクトリ" "出力先ディレクトリ"

test_start "doc-plan.md が出力先ディレクトリを絶対パスとして確定させる"
# Why: 計画「出力先ディレクトリの絶対パスを必ず確定させる」。
assert_contains "$plan" "絶対パス" "絶対パス明示"

test_start "doc-plan.md が対象コード特定に Grep / Glob を指示する"
assert_contains "$plan" "Grep|grep" "Grep 指示"
assert_contains "$plan" "Glob|glob" "Glob 指示"

test_start "doc-plan.md が中間レポート・最終 2 ドキュメントの章立て設計を指示する"
assert_contains "$plan" "章立て|章構成" "章立て設計"
assert_contains "$plan" "user-guide|ユーザー.*ドキュメント|ユーザー向け" "user-guide.md 章立て"
assert_contains "$plan" "detail|詳細.*ドキュメント|詳細" "detail.md 章立て"

test_start "doc-plan.md がコード変更・ドキュメント執筆を禁止している"
assert_contains "$plan" "禁止|やらない|書かない|変更しない" "禁止事項"

# doc-investigate: plan の参照 + 構造化 6 項目
inv="$INSTRUCTION_DIR/doc-investigate.md"
test_start "doc-investigate.md が {report:doc-plan.md} を参照する"
# Why: plan の成果物を入力とする（配線要件）。
assert_contains "$inv" '\{report:doc-plan\.md\}' "{report:doc-plan.md} 参照"

test_start "doc-investigate.md がクラス / 関数 / データフロー / 外部依存 / 起動経路の抽出を指示する"
# Why: 要件 25。構造化 5〜6 項目。
assert_contains "$inv" "クラス" "クラス"
assert_contains "$inv" "関数" "関数"
assert_contains "$inv" "データフロー|データ ?フロー" "データフロー"
assert_contains "$inv" "外部依存|依存" "外部依存"
assert_contains "$inv" "起動経路|到達経路|入口|エントリ" "起動経路"

test_start "doc-investigate.md がファイル:行 の明記を求める"
# Why: 「ファイル:行 を必ず添える」が行動原則。
assert_contains "$inv" "ファイル:行|ファイル.*行|行番号|:L[0-9]" "ファイル:行 明記"

test_start "doc-investigate.md がコード変更・ドキュメント執筆を禁止している"
assert_contains "$inv" "禁止|やらない|書かない|変更しない" "禁止事項"

# write-user-doc: 非エンジニア向け / 日本語 / LP 品質 / 必須セクション
userdoc="$INSTRUCTION_DIR/write-user-doc.md"
test_start "write-user-doc.md が {report:doc-plan.md} と {report:doc-investigate.md} を参照する"
assert_contains "$userdoc" '\{report:doc-plan\.md\}' "{report:doc-plan.md} 参照"
assert_contains "$userdoc" '\{report:doc-investigate\.md\}' "{report:doc-investigate.md} 参照"

test_start "write-user-doc.md が出力先を <output_dir>/user-guide.md に指定する"
# Why: plan で確定した出力先 + 固定ファイル名（計画決定）。
assert_contains "$userdoc" "user-guide\.md" "user-guide.md"

test_start "write-user-doc.md が想定読者を非エンジニアと明記する"
# Why: 要件 16。
assert_contains "$userdoc" "非エンジニア" "非エンジニア"

test_start "write-user-doc.md が LP 品質を要求する"
assert_contains "$userdoc" "LP" "LP 品質"

test_start "write-user-doc.md が必須セクション（概要 / 起動方法 / ユースケース）を列挙する"
assert_contains "$userdoc" "概要|機能の概要" "機能の概要"
assert_contains "$userdoc" "起動方法|使い方" "起動方法・使い方"
assert_contains "$userdoc" "ユースケース" "ユースケース"

test_start "write-user-doc.md が出力言語を日本語、形式を Markdown と明記する"
assert_contains "$userdoc" "日本語" "日本語"
assert_contains "$userdoc" "Markdown|マークダウン" "Markdown"

test_start "write-user-doc.md が技術用語の多用を避けるよう明記する"
# Why: 計画「技術用語の多用を避ける、専門用語は必ず噛み砕く」。
assert_contains "$userdoc" "技術用語|専門用語" "技術用語抑制"

test_start "write-user-doc.md が user-guide.md 以外を書き換えないと明記する"
assert_contains "$userdoc" "user-guide\.md 以外|対象ファイル以外|スコープ外" "スコープ限定"

# write-detail-doc: Mermaid 必須 / クラス・関数 / データフロー
detail="$INSTRUCTION_DIR/write-detail-doc.md"
test_start "write-detail-doc.md が {report:doc-plan.md} と {report:doc-investigate.md} を参照する"
assert_contains "$detail" '\{report:doc-plan\.md\}' "{report:doc-plan.md} 参照"
assert_contains "$detail" '\{report:doc-investigate\.md\}' "{report:doc-investigate.md} 参照"

test_start "write-detail-doc.md が出力先を <output_dir>/detail.md に指定する"
assert_contains "$detail" "detail\.md" "detail.md"

test_start "write-detail-doc.md が Mermaid 図の必須配置（≥1）を明記する"
# Why: 要件 15。Mermaid 図を 1 つ以上含める。
assert_contains "$detail" "Mermaid" "Mermaid"
assert_contains "$detail" "1 ?つ以上|必ず|最低.*1|≥ ?1" "Mermaid ≥1 必須"

test_start "write-detail-doc.md が Mermaid をテキスト記法で埋め込むよう明記する"
# Why: 「画像で生成しない、必ず Mermaid テキスト記法」。
assert_contains "$detail" "mermaid|\`\`\`mermaid|テキスト記法" "Mermaid テキスト記法"

test_start "write-detail-doc.md が必須セクション（対象ファイル一覧 / 主要クラス・関数 / データフロー）を列挙する"
assert_contains "$detail" "対象ファイル" "対象ファイル一覧"
assert_contains "$detail" "クラス|関数|責務" "主要クラス・関数・責務"
assert_contains "$detail" "データフロー|データ ?フロー" "データフロー"

test_start "write-detail-doc.md が出力言語を日本語、形式を Markdown と明記する"
assert_contains "$detail" "日本語" "日本語"
assert_contains "$detail" "Markdown|マークダウン" "Markdown"

test_start "write-detail-doc.md が detail.md 以外を書き換えないと明記する"
assert_contains "$detail" "detail\.md 以外|対象ファイル以外|スコープ外" "スコープ限定"

# review-doc: 観点優先順 / 指摘のみ / Mermaid 一致
review="$INSTRUCTION_DIR/review-doc.md"
test_start "review-doc.md が観点優先順「読みやすさ → 正確性」を明記する"
assert_contains "$review" "読みやすさ" "読みやすさ"
assert_contains "$review" "正確性" "正確性"

test_start "review-doc.md が {report:doc-plan.md} と {report:doc-investigate.md} を参照する"
assert_contains "$review" '\{report:doc-plan\.md\}' "{report:doc-plan.md} 参照"
assert_contains "$review" '\{report:doc-investigate\.md\}' "{report:doc-investigate.md} 参照"

test_start "review-doc.md が生成済みの user-guide.md / detail.md を Read するよう指示する"
# Why: 本体を Read して指摘を作る（本体編集は不可）。
assert_contains "$review" "user-guide\.md" "user-guide.md Read"
assert_contains "$review" "detail\.md" "detail.md Read"

test_start "review-doc.md が Mermaid 図と実装の一致確認を指示する"
assert_contains "$review" "Mermaid" "Mermaid 一致"

test_start "review-doc.md が本体編集を禁止している"
assert_contains "$review" "編集しない|修正しない|本体.*禁止|Edit.*禁止" "本体編集禁止"

test_start "review-doc.md が severity または重要度の付与を指示する"
# Why: 計画「指摘リスト（severity / 該当ファイル / 章節 / 内容 / 修正方向 / finding_id）」。
assert_contains "$review" "severity|重要度" "severity 付与"

# fix-doc: 指摘反映 / 出力先限定
fix="$INSTRUCTION_DIR/fix-doc.md"
test_start "fix-doc.md が {report:doc-review.md} を参照する"
# Why: review 指摘を入力とする。
assert_contains "$fix" '\{report:doc-review\.md\}' "{report:doc-review.md} 参照"

test_start "fix-doc.md が {report:doc-plan.md} を参照する（出力先パス取得）"
assert_contains "$fix" '\{report:doc-plan\.md\}' "{report:doc-plan.md} 参照"

test_start "fix-doc.md が編集対象を user-guide.md と detail.md のみに限定する"
assert_contains "$fix" "user-guide\.md" "user-guide.md"
assert_contains "$fix" "detail\.md" "detail.md"

test_start "fix-doc.md が言語を日本語、形式を Markdown と明記する"
assert_contains "$fix" "日本語" "日本語"
assert_contains "$fix" "Markdown|マークダウン" "Markdown"

test_start "fix-doc.md が出力先以外の変更を禁止する"
assert_contains "$fix" "出力先以外|対象.*以外|スコープ外|禁止" "出力先限定"

print_summary
