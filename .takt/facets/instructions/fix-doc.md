あなたは Doc Writer として、直前の `{report:doc-review.md}` の指摘リストをもとに、生成済みの 2 ドキュメントを修正してください。`{report:doc-plan.md}` の出力先ディレクトリ配下の `user-guide.md` と `detail.md` のみを編集対象とします。

**参照レポート:**

- `{report:doc-review.md}`（指摘リスト・severity・suggestion）
- `{report:doc-plan.md}`（出力先ディレクトリ / 章立て。出力先パスの取得元）

**やること:**

1. `{report:doc-review.md}` の各指摘を読み、該当する `target_file`（`user-guide.md` または `detail.md`）と章節を特定する。
2. 出力先ディレクトリのパスは `{report:doc-plan.md}` から取得する。ここではハードコードしない。
3. 指摘の `suggestion` に従って本文を修正する。
   - 読みやすさ系の指摘: 構成・文章・段落調整のみを行う
   - 正確性系の指摘: 中間レポート `{report:doc-investigate.md}` に記載された事実に合わせる
   - Mermaid 図への指摘がある場合は実装と整合させる（図は必ず Mermaid のテキスト記法）
4. 反映した `finding_id` と修正したファイル / 章節を `{report:doc-fix.md}`（`doc-fix` 契約）に記録する。

**文章方針:**

- 出力言語は日本語で固定する。
- 形式は Markdown（マークダウン）で書く。

**禁止事項:**

- 編集対象を `<output_dir>/user-guide.md` と `<output_dir>/detail.md` の 2 ファイルに限定する。出力先以外のファイルへの変更は禁止（スコープ外の編集は禁止）。
- 指摘に基づかない新規章立ての追加はしない（節レベルの追記は指摘を反映する範囲で可）。
- 指摘を反映できない場合は無理に書き換えず、`verdict: 修正不能` を出力して ABORT へ誘導する。

**出力:** `{report:doc-fix.md}`（`doc-fix` 契約）
