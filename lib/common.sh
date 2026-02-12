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

# エージェントIDからペインターゲットを解決
resolve_pane_target() {
    local agent_id="$1"
    case "$agent_id" in
        commander) echo "ols-commander:0.0" ;;
        sergeant)  echo "ols-team:0.0" ;;
        soldier*)
            local num="${agent_id#soldier}"
            # サージェントが Pane 0 を使うため、ソルジャーは Pane num
            echo "ols-team:0.${num}"
            ;;
    esac
}

# @agent_id からペインを逆引き
find_pane_by_agent_id() {
    local target_id="$1"
    local session="$2"
    tmux list-panes -t "$session" -F '#{pane_index} #{@agent_id}' \
        | awk -v id="$target_id" '$2 == id {print $1}'
}
