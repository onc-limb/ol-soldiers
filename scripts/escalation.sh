#!/bin/bash
# scripts/escalation.sh - 応答なしエージェントの強制復帰
# 使い方: escalation.sh <agent_id> <pane_id> <project_root>
set -euo pipefail

AGENT_ID="$1"
PANE_ID="$2"
PROJECT_ROOT="$3"
LOG_FILE="${PROJECT_ROOT}/.ol-soldiers/logs/watcher.log"

log() {
    echo "[$(date '+%H:%M:%S')] [escalation:${AGENT_ID}] $*" >> "$LOG_FILE"
}

log "Phase C: /clear による強制復帰を実行"

# 1. Escape で入力状態をクリア
printf '\x1b' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
sleep 0.5

# 2. /clear を送信
printf '%s' '/clear' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
sleep 0.2
printf '\r' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
sleep 3

# 3. 復帰指示を送信
RECOVERY_MSG="${AGENT_ID} です。/clear 後の復帰: .ol-soldiers/roles/ の自分のロールファイルを読み、タスクYAMLを確認して再開。"
printf '%s' "$RECOVERY_MSG" | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
sleep 0.2
printf '\r' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste

log "復帰指示を送信完了"
