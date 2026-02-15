# ol-soldiers

Claude Code インスタンスを並列で動かすマルチエージェントシステム。3層の指揮系統でタスクを自動分解・並列実行・集約する。

## What is this?

Claude Code の単一セッションでは、1つのタスクを順番にしか処理できない。大規模な変更や複数ファイルにまたがる作業は、人間が手動で分割・調整する必要がある。

ol-soldiers は **Commander → Sergeant → Soldiers** の3層指揮系統で、命令を自動的にサブタスクに分解し、複数の Claude Code インスタンスで並列実行する。人間は Commander に命令を出すだけで、あとは自動で分解・実行・集約される。

## Architecture

### 指揮系統

```
Human（操作者）
  │  自然言語で指示
  ▼
Commander（指揮官）
  │  命令を構造化し Sergeant に委譲。自分では実装しない。
  ▼
Sergeant（軍曹）
  │  命令をサブタスクに分解し Soldiers に割り当て。自分では実装しない。
  ▼
Soldiers（兵士 ×N）
  並列にタスクを実装。指定されたスコープ内でのみ作業する。
```

### WezTerm レイアウト

```
Tab 1: OLS: Command                Tab 2: OLS: Soldiers
┌──────────────┬──────────────┐    ┌──────────┬──────────┐
│  Commander   │  Sergeant    │    │ Soldier1 │ Soldier2 │
│  (opus)      │  (opus)      │    ├──────────┼──────────┤
└──────────────┴──────────────┘    │ Soldier3 │ Soldier4 │
                                   └──────────┴──────────┘
```

### 通信方式

エージェント間の通信は YAML ファイルと `inbox_write.sh` で行う。直接の `wezterm cli send-text` 使用は禁止（F-008）。

```
Commander → Sergeant:  commander_to_sergeant.yaml に命令を書く → inbox_write.sh で通知
Sergeant  → Soldiers:  tasks/soldierN.yaml にタスクを書く → inbox_write.sh で通知
Soldiers  → Sergeant:  reports/soldierN_report.yaml にレポートを書く → inbox_write.sh で通知
Sergeant  → Commander: inbox_write.sh で完了通知
```

`inbox_watcher.sh` が各エージェントの inbox ファイルを `fswatch` で監視し、変更を検知すると WezTerm ペインにナッジメッセージを自動送信する。

## Prerequisites

| ツール | 用途 | インストール |
|--------|------|-------------|
| [WezTerm](https://wezfurlong.org/wezterm/) | ターミナル・ペイン管理 | `brew install --cask wezterm` |
| [Claude Code](https://claude.ai/download) | AI エージェント | `npm install -g @anthropic-ai/claude-code` |
| [fswatch](https://emcrisostomo.github.io/fswatch/) | ファイル変更監視 | `brew install fswatch` |

## Installation

```bash
git clone <repository-url> ol-soldiers
cd ol-soldiers
bash install.sh
```

`install.sh` は以下を行う:
1. wezterm, claude, fswatch の依存チェック
2. `~/.ol-soldiers/` にコマンド・スクリプト・テンプレートをコピー
3. PATH 追加の案内を表示

表示された案内に従い、シェル設定に PATH を追加:

```bash
export PATH="$HOME/.ol-soldiers/commands:$PATH"
```

## Quick Start

```bash
# プロジェクトディレクトリに移動
cd ~/projects/my-app

# エージェントを起動（デフォルト: Soldier 4名）
ols-start

# Soldier 数を指定して起動
ols-start 6

# 全エージェントを停止
ols-stop

# テンプレートを最新に更新（ロールファイルのみ）
ols-update

# CLAUDE.md も含めて更新
ols-update --claude
```

## Usage

### 基本ワークフロー

1. **起動**: `ols-start` でプロジェクトディレクトリに `.ol-soldiers/` を生成し、WezTerm にペインを作成
2. **命令**: Tab 1 の Commander ペインに自然言語で指示を入力
3. **自動実行**: Commander が命令を構造化 → Sergeant がサブタスクに分解 → Soldiers が並列実行
4. **結果確認**: Commander が集約された結果を報告。`dashboard.md` で進捗を確認可能

### 具体例

```
# Commander ペインで：
「認証機能を実装して。ログインAPI、ユーザー登録API、JWT ミドルウェアが必要」

# 自動で以下が行われる:
# 1. Commander → commander_to_sergeant.yaml に命令を構造化
# 2. Sergeant → tasks/soldier1.yaml（ログインAPI）, tasks/soldier2.yaml（ユーザー登録API）, ...
# 3. Soldiers が並列に実装
# 4. Sergeant がレポートを集約、Commander が結果を報告
```

## Directory Structure

### リポジトリ構造

```
ol-soldiers/
├── install.sh                          # 初回セットアップスクリプト
├── commands/
│   ├── ols-start                       # エージェント起動
│   ├── ols-stop                        # 全エージェント停止
│   └── ols-update                      # テンプレート更新
├── lib/
│   └── common.sh                       # 共通関数ライブラリ
├── scripts/
│   ├── inbox_write.sh                  # アトミックメッセージ書き込み
│   ├── inbox_watcher.sh                # ファイル監視デーモン
│   └── get_agent_id.sh                 # ペインの agent_id 取得
└── templates/
    ├── CLAUDE.md.template              # 全エージェント共通の憲法テンプレート
    ├── task.yaml.template              # タスク YAML スキーマ
    ├── report.yaml.template            # レポート YAML スキーマ
    └── roles/
        ├── commander.md.template       # 指揮官の役割定義
        ├── sergeant.md.template        # 軍曹の役割定義
        └── soldier.md.template         # 兵士の役割定義
```

### ランタイム構造（`ols-start` 実行後に生成）

```
project/
├── CLAUDE.md                           # テンプレートからコピーされた憲法
└── .ol-soldiers/
    ├── config.yaml                     # プロジェクト固有設定
    ├── dashboard.md                    # 進捗表示
    ├── roles/
    │   ├── commander.md                # テンプレートからコピー
    │   ├── sergeant.md
    │   └── soldier.md
    ├── queue/
    │   ├── commander_to_sergeant.yaml  # Commander → Sergeant 命令
    │   ├── tasks/
    │   │   └── soldierN.yaml           # Sergeant → Soldier タスク割り当て
    │   ├── reports/
    │   │   └── soldierN_report.yaml    # Soldier → Sergeant 完了報告
    │   └── inbox/
    │       ├── commander.yaml          # Commander のインボックス
    │       ├── sergeant.yaml           # Sergeant のインボックス
    │       └── soldierN.yaml           # Soldier のインボックス
    └── logs/
        ├── pane_map                    # agent_id ↔ pane_id の対応（TSV）
        ├── watcher.pids                # inbox_watcher プロセスの PID
        └── watcher.log                 # 監視ログ
```

## Roles

### Commander（指揮官）

人間の意図を構造化し、Sergeant に委譲する。自分では一切実装しない。

- **通信先**: Human ↔ 命令/結果報告、Sergeant → 命令 / ← 完了報告
- **禁止**: ソースコード編集、ファイル作成、Soldier への直接指示
- **主要ファイル**: `commander_to_sergeant.yaml`（Write）、`reports/`（Read）

### Sergeant（軍曹）

Commander の命令をサブタスクに分解し、Soldier に割り当てる。自分では一切実装しない。

- **通信先**: Commander ← 命令 / → 完了報告、Soldiers → タスク / ← 報告
- **禁止**: ソースコード編集、ファイル作成、Human への直接連絡
- **主要ファイル**: `tasks/*.yaml`（Write）、`reports/`（Read）、`dashboard.md`（Write）

### Soldier（兵士）

Sergeant から割り当てられたタスクを、`target_path` 内で実装する。

- **通信先**: Sergeant ← タスク / → 完了報告
- **禁止**: `target_path` 外の編集、他 Soldier との通信、Human への直接連絡
- **主要ファイル**: `tasks/soldierN.yaml`（Read）、`reports/soldierN_report.yaml`（Write）

## Communication Protocol

### 3層防御モデル

| 層 | 名称 | 内容 |
|----|------|------|
| 第1層 | 禁止行動リスト | F-001〜F-008（while+sleep禁止、指揮系統飛越禁止 等） |
| 第2層 | 許可行動ホワイトリスト | 各ロールごとに許可された行動のみ実行可能 |
| 第3層 | ファイルアクセス制御 | パス単位の Read/Write 権限 |

### メッセージ送信

エージェントは `inbox_write.sh` を使ってメッセージを送信する:

```bash
bash ~/.ol-soldiers/scripts/inbox_write.sh <宛先agent_id> "<メッセージ>" <種別> <送信元>
```

メッセージ種別:
- `cmd_new` - 新しい命令
- `task_assigned` - タスク割り当て
- `report_received` - 完了報告
- `general` - その他

### inbox_watcher.sh

バックグラウンドで各エージェントの inbox ファイルを `fswatch` で監視する。変更を検知すると、メッセージ種別に応じたナッジを WezTerm ペインに送信する。排他ロックは `mkdir` ベース（POSIX 準拠、macOS 互換）。

## Implemented Features

### Phase 1: 最小構成（手動通知）

- [x] `ols-start` - WezTerm セッション作成、Claude CLI 起動
- [x] `CLAUDE.md.template` - 全エージェント共通の憲法
- [x] `task.yaml.template` / `report.yaml.template` - YAML スキーマ
- [x] `common.sh` - 共通関数（ログ、パス解決、ペイン管理）
- [x] `install.sh` - 初回セットアップ

### Phase 2: 自動化（イベント駆動 + Sergeant 層）

- [x] `inbox_write.sh` - `mkdir` ベースの排他ロック付きアトミック書き込み
- [x] `inbox_watcher.sh` - `fswatch` + `stat` フォールバックによるファイル監視
- [x] `ols-stop` - Ctrl-C → /exit → kill-pane の3段階停止
- [x] `ols-update` - テンプレート更新（`--claude` オプション対応）
- [x] Sergeant 層追加 - 3層指揮系統の完成
- [x] ロールテンプレート分離 - `roles/commander.md`, `sergeant.md`, `soldier.md`
- [x] `--append-system-prompt` によるロール注入
- [x] `get_agent_id.sh` - WezTerm ペインからの agent_id 取得

## Roadmap

### Phase 3: 堅牢化

- `ols-status` コマンド（エージェント生死確認、タスク状態表示）
- エスカレーション機能（30秒→再ナッジ、60秒→Escape+再ナッジ、120秒→/clear 強制リセット）
- Bloom レベルによるモデル切替（L1-3→sonnet、L4-6→opus）
- ペインタイトル表示
- テンプレート堅牢化（安全規則強化）

### Phase 4: 拡張

- タスク依存関係管理（DAG）
- スキル自動発見
- 外部通知（ntfy）
- dashboard.md リッチ化
- 動的スケーリング
- Memory MCP 連携
