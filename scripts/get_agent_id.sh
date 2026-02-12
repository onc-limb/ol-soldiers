#!/bin/bash
# scripts/get_agent_id.sh - 現在のペインのagent_idを取得する
# tmux display-message -p -t "$TMUX_PANE" '#{@agent_id}' の代替
set -euo pipefail

PANE_MAP="$(pwd)/.ol-soldiers/logs/pane_map"

if [ ! -f "$PANE_MAP" ]; then
    echo "[ERROR] pane_map が見つかりません。ols-start を先に実行してください。" >&2
    exit 1
fi

awk -F'\t' -v pid="$WEZTERM_PANE" '$2 == pid {print $1}' "$PANE_MAP"
