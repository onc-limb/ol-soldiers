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

# pane_mapファイルのパスを取得
get_pane_map_file() {
    local project_root="${1:-$(pwd)}"
    echo "${project_root}/.ol-soldiers/logs/pane_map"
}

# agent_id と pane_id の対応を保存
save_pane_mapping() {
    local agent_id="$1"
    local pane_id="$2"
    local map_file="$3"
    printf '%s\t%s\n' "$agent_id" "$pane_id" >> "$map_file"
}

# agent_id から WezTerm pane_id を取得
find_pane_by_agent_id() {
    local target_id="$1"
    local map_file="$2"
    awk -F'\t' -v id="$target_id" '$1 == id {print $2}' "$map_file"
}

# WezTerm pane_id から agent_id を逆引き
find_agent_by_pane_id() {
    local pane_id="$1"
    local map_file="$2"
    awk -F'\t' -v pid="$pane_id" '$2 == pid {print $1}' "$map_file"
}

# WezTermペインにテキストを送信（Enter付き）
send_text_to_pane() {
    local pane_id="$1"
    local text="$2"
    printf '%s\r' "$text" | wezterm cli send-text --pane-id "$pane_id" --no-paste
}
