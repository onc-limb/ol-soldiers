#!/bin/bash
# tests/feature-doc/test_output_contracts.sh - feature-doc output-contract の必須フィールド検証
#
# 計画レポートで各 contract に要求された項目（機能名 / 出力先 / 対象ファイル /
# 章立て / 判定 / 指摘フィールド等）が template に含まれているかを検証する。

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../lib/assert.sh
source "$SCRIPT_DIR/../lib/assert.sh"

CONTRACT_DIR="$REPO_ROOT/.takt/facets/output-contracts"

# doc-plan: 機能名 / 出力先 / 対象ファイル / 章立て / 判定
plan="$CONTRACT_DIR/doc-plan.md"
test_start "output-contracts/doc-plan.md が必須フィールド（機能名 / 出力先 / 対象ファイル / 章立て / 判定）を列挙する"
assert_contains "$plan" "機能名" "機能名"
assert_contains "$plan" "出力先|出力 ?ディレクトリ" "出力先ディレクトリ"
assert_contains "$plan" "対象ファイル" "対象ファイル一覧"
assert_contains "$plan" "章立て|章構成" "章立て"
assert_contains "$plan" "判定|verdict|ready|info_gap" "判定フィールド"

test_start "output-contracts/doc-plan.md が user-guide.md と detail.md の章立てを分けて要求する"
# Why: 「user-guide.md 章立て / detail.md 章立て」の 2 種類を分けて記録。
assert_contains "$plan" "user-guide" "user-guide.md 章立て"
assert_contains "$plan" "detail" "detail.md 章立て"

# doc-investigate: 構造化 5〜6 項目
inv="$CONTRACT_DIR/doc-investigate.md"
test_start "output-contracts/doc-investigate.md が構造化抽出項目（ファイル:行 / 責務 / 呼び出し関係 / データフロー / 起動経路 / 未確認）を要求する"
assert_contains "$inv" "ファイル:行|ファイル.*行|行番号" "ファイル:行"
assert_contains "$inv" "責務" "責務"
assert_contains "$inv" "呼び出し関係|呼び出し" "呼び出し関係"
assert_contains "$inv" "データフロー|データ ?フロー" "データフロー"
assert_contains "$inv" "起動経路|到達経路|入口" "起動経路"
assert_contains "$inv" "未確認|unknown" "未確認事項"

# doc-write: 書き込み結果
write="$CONTRACT_DIR/doc-write.md"
test_start "output-contracts/doc-write.md が書き込み先絶対パスを要求する"
# Why: 「書き込み先絶対パス / 適用した章立て / 含めた Mermaid 図（detail のみ）/ 判定」。
assert_contains "$write" "書き込み先|出力先|絶対パス|path" "書き込み先"

test_start "output-contracts/doc-write.md が適用した章立てを要求する"
assert_contains "$write" "章立て|章構成|適用" "章立て記録"

test_start "output-contracts/doc-write.md が Mermaid 図の記録フィールドを持つ"
# Why: detail のみだが、共通契約として Mermaid 有無の記録を残す。
assert_contains "$write" "Mermaid" "Mermaid 記録"

test_start "output-contracts/doc-write.md が判定（執筆完了 / 執筆失敗）を要求する"
assert_contains "$write" "執筆完了|執筆失敗|verdict|judge" "執筆判定"

# doc-review: 指摘リスト
review="$CONTRACT_DIR/doc-review.md"
test_start "output-contracts/doc-review.md が指摘フィールド（severity / target_file / 章節 / 内容 / suggestion / finding_id）を要求する"
assert_contains "$review" "severity|重要度" "severity"
assert_contains "$review" "target_file|対象ファイル|ファイル名" "target_file"
assert_contains "$review" "章節|セクション|見出し" "章節"
assert_contains "$review" "内容|description|指摘内容" "内容"
assert_contains "$review" "suggestion|修正方向|修正提案" "suggestion"
assert_contains "$review" "finding_id|id" "finding_id"

test_start "output-contracts/doc-review.md が判定（指摘なし / 指摘あり）を要求する"
assert_contains "$review" "指摘なし|指摘あり|verdict" "review 判定"

# doc-fix: 反映指摘一覧
fix="$CONTRACT_DIR/doc-fix.md"
test_start "output-contracts/doc-fix.md が反映した finding_id 一覧を要求する"
# Why: 「反映した指摘 finding_id 一覧 / 修正したファイルと章節 / 判定」。
assert_contains "$fix" "finding_id|反映した指摘" "反映した finding_id"

test_start "output-contracts/doc-fix.md が修正したファイルと章節を要求する"
assert_contains "$fix" "修正.*ファイル|変更.*ファイル|修正した" "修正ファイル"
assert_contains "$fix" "章節|セクション|見出し" "章節"

test_start "output-contracts/doc-fix.md が判定（修正完了 / 修正不能）を要求する"
assert_contains "$fix" "修正完了|修正不能|verdict" "fix 判定"

# 全 contract で三連バッククォート + markdown テンプレート形式
for name in doc-plan doc-investigate doc-write doc-review doc-fix; do
    path="$CONTRACT_DIR/${name}.md"
    test_start "output-contracts/${name}.md が \`\`\`markdown フェンスでテンプレートを囲っている"
    # Why: 既存 intake.md 等と同形式（三連バッククォート + markdown 言語タグ）。
    assert_contains "$path" '```markdown' 'markdown フェンス'
done

print_summary
