# ASSUMPTIONS

`ol-soldiers-style` ワークフローを「ユーザー対話なしで PR 作成まで完結させる」方式へ書き換える際に、ユーザー指示で明示されていなかった点を以下のように仮定して進めた。

## 2026-04-26 ol-soldiers-style.yaml 改修

### 1. PR 作成 step の persona

- **不足していた情報**: 「PR 作成まで完結させる」という指示はあったが、その責務を担う persona の指定はなかった。
- **採用した推測**: 既存の `facilitator` に PR 作成役割を統合した（新 persona は作成しない）。
    - 理由: facilitator は元来「サイクル要約・エスカレーション要約」を担う進行役であり、PR 本文への要約転記は同じ責務領域に収まる。新 persona を作るより最小変更で整合的。
- **影響範囲**: `.takt/facets/personas/facilitator.md`、`.takt/facets/instructions/pr-create.md`、`.takt/workflows/ol-soldiers-style.yaml` の `pr_create` step。

### 2. 完了状況の判定区分

- **不足していた情報**: PR の完了状況を何種類に区切るか指示なし。
- **採用した推測**: `success` / `partial` / `blocked` の 3 区分を採用。
    - `success`: `goal-review.md` が `approved` かつ open_questions / blockers 共に空
    - `partial`: `approved` だが open_questions / assumptions が残る
    - `blocked`: `goal-review.md` が `blocked` または cycle 上限到達
- **影響範囲**: `pr-create.md` instruction / output-contract、PR タイトルの prefix（`partial` / `blocked` の場合 `[partial] ` / `[blocked] `）。

### 3. PR の draft フラグ運用

- **不足していた情報**: PR を draft で作るか ready で作るかの指示なし。
- **採用した推測**: `success` 以外（`partial` / `blocked`）は `--draft` で作成する。
    - 理由: 不足情報や blocker が残る PR は、ユーザーレビューで回答を得てから ready に上げる想定。レビュアーが「マージ可能か」を一目で判断できる。
- **影響範囲**: `pr-create.md` instruction の Bash 手順。

### 4. ブランチ運用

- **不足していた情報**: PR を切るための作業ブランチの命名規約は未指定。
- **採用した推測**: 保護ブランチ（main / master）上で実行された場合に限り、`takt/{slug}` 形式で切り替える。`{slug}` は `intake.md` の title から英小文字とハイフンで生成。既に作業ブランチ上にいる場合はそのまま使う。
- **影響範囲**: `pr-create.md` instruction の手順 1。

### 5. サイクル上限到達時の扱い

- **不足していた情報**: 旧仕様では `escalate_cycle_limit` でユーザー対話に逃げていた。新仕様での挙動指示なし。
- **採用した推測**: 上限到達時も `pr_create` へ進み、PR 本文の「未達成 Done」「blocker」セクションに状況を明記する（`blocked` 完了状況）。
- **影響範囲**: `loop_monitors` の `judge.rules`、`pr-create.md` の判定区分。

### 6. open_questions の上限

- **不足していた情報**: PR 本文に転記する open_questions の項目数上限指示なし。
- **採用した推測**: `intake.md` 段階では最大 3 項目、PR 本文集約段階では最大 5 項目（execute / goal-review からの追加分を許容）。
- **影響範囲**: `intake.md` instruction、`pr-create.md` instruction。

### 7. 旧 escalate-summary instruction / output-contract の処遇

- **不足していた情報**: 既存の escalate-summary 関連ファイルを残すか削除するかの指示なし。
- **採用した推測**: workflow から参照されなくなるため削除した。`pr-create.md` がその責務（成果物要約・blocker 整理・確認事項列挙）を引き継ぐ。
- **影響範囲**: `.takt/facets/instructions/escalate-summary.md`、`.takt/facets/output-contracts/escalate-summary.md` を削除。テスト群もそれに合わせて更新。
