#!/bin/bash
# lib/common.sh - 共通関数

# スクリプトのルートディレクトリ
OLS_GLOBAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ログ出力
ols_log() {
    local level="$1"
    shift
    echo "[$(date '+%H:%M:%S')] [${level}] $*"
}

# プロジェクトの .ol-soldiers ディレクトリを取得
get_ols_dir() {
    local project_root="${1:-$(pwd)}"
    echo "${project_root}/.ol-soldiers"
}

# @agent_id からペインインデックスを取得
find_pane_by_agent_id() {
    local target_id="$1"
    local session="$2"
    tmux list-panes -t "$session" -F '#{pane_index} #{@agent_id}' \
        | awk -v id="$target_id" '$2 == id {print $1}'
}

# エージェントIDからペインターゲット文字列を解決
resolve_pane_target() {
    local agent_id="$1"
    local session="${2:-ols}"
    local pane_index
    pane_index=$(find_pane_by_agent_id "$agent_id" "$session")
    echo "${session}:0.${pane_index}"
}
