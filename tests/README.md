# ol-soldiers-style ワークフローのテスト

`.takt/workflows/ol-soldiers-style.yaml` と関連する facets (`.takt/facets/personas/`,
`.takt/facets/instructions/`, `.takt/facets/output-contracts/`) の構造・内容・
相互参照を検証するテストスイート。

## 実行

```bash
bash tests/run.sh
```

個別のスイートを実行する場合:

```bash
bash tests/workflow/test_structure.sh
bash tests/workflow/test_workflow_yaml.sh
# 以下同様
```

## 構成

| ファイル | 役割 |
|----------|------|
| `tests/run.sh` | エントリポイント (全スイート実行) |
| `tests/lib/assert.sh` | bash 用アサーション関数 |
| `tests/lib/yaml_query.mjs` | YAML クエリ (takt 同梱の `yaml` を借用) |
| `tests/lib/run_yaml_query.sh` | `yaml_query.mjs` のラッパ |
| `tests/workflow/test_structure.sh` | ファイル存在 + `takt workflow doctor` による構造診断 |
| `tests/workflow/test_workflow_yaml.sh` | `workflow.yaml` の数値・遷移ルール検証 |
| `tests/workflow/test_personas.sh` | 6 persona のコンテキスト境界・役割境界の検証 |
| `tests/workflow/test_instructions.sh` | instruction 仕様 (URL 判定 / AND 判定 / 要約) |
| `tests/workflow/test_output_contracts.sh` | output-contract の必須フィールド |
| `tests/workflow/test_cross_references.sh` | persona/instruction/format 参照の整合性 |
| `tests/workflow/test_generic_constraints.sh` | 汎用性担保 (具体パス・コマンド・ol-soldiers スクリプトが漏れていないか) |
| `tests/workflow/test_integration_flow.sh` | intake→plan_split→…→COMPLETE/escalate の全遷移疎通 |

## 前提

- Node.js (ESM)
- `takt` CLI (`/opt/homebrew/lib/node_modules/takt/bin/takt`)
- takt 同梱の `yaml` パッケージ (`/opt/homebrew/lib/node_modules/takt/node_modules/yaml`)

`takt` のインストール先が異なる場合は以下で上書きできる:

```bash
TAKT_YAML_MODULE=/custom/path/to/yaml/dist/index.js bash tests/run.sh
```

## 実装前の失敗について

このテストスイートは実装 (`write_tests` の次の `implement` step) の前に書かれる。
そのため実装前の時点では **すべて or 大半のアサーションが失敗するのが正常**。
各スイートは対象ファイルが無い場合はスキップするか明示的に失敗する。
