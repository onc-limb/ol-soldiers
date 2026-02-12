#!/bin/bash
# scripts/inbox_watcher.sh - ファイル変更を監視してエージェントを起こす
# 使い方: inbox_watcher.sh <agent_id> <tmux_target> <project_root>
set -euo pipefail

AGENT_ID="$1"
TMUX_TARGET="$2"
PROJECT_ROOT="$3"
INBOX_FILE="${PROJECT_ROOT}/.ol-soldiers/queue/inbox/${AGENT_ID}.yaml"
LOG_FILE="${PROJECT_ROOT}/.ol-soldiers/logs/watcher.log"

log() {
    echo "[$(date '+%H:%M:%S')] [watcher:${AGENT_ID}] $*" >> "$LOG_FILE"
}

touch "$INBOX_FILE"
log "監視開始: ${INBOX_FILE}"

while true; do
    # fswatch: ファイル変更イベントを1件待機（ブロッキング、CPU消費ゼロ）
    fswatch -1 "$INBOX_FILE" >/dev/null 2>&1

    log "変更検知"

    # 最新メッセージの type を読み取る
    LATEST_TYPE=$(tail -5 "$INBOX_FILE" | grep "type:" | tail -1 | awk '{print $2}' | tr -d '"')

    case "$LATEST_TYPE" in
        task_assigned)
            NUDGE="タスクYAMLが割り当てられました。cat .ol-soldiers/queue/tasks/${AGENT_ID}.yaml を読んで作業を開始してください。"
            ;;
        cmd_new)
            NUDGE="新しい命令が到着しました。cat .ol-soldiers/queue/commander_to_sergeant.yaml を読んで対応してください。"
            ;;
        report_received)
            NUDGE="レポートが届きました。.ol-soldiers/queue/reports/ を確認してください。"
            ;;
        *)
            NUDGE="新しいメッセージが inbox にあります。cat .ol-soldiers/queue/inbox/${AGENT_ID}.yaml で確認してください。"
            ;;
    esac

    # tmux send-keys で通知（-l でリテラル送信後、Enter を別送信）
    tmux send-keys -l -t "$TMUX_TARGET" "$NUDGE"
    sleep 0.2
    tmux send-keys -t "$TMUX_TARGET" Enter
    log "通知送信: ${NUDGE}"

    # 連続イベントのデバウンス（1秒待つ）
    sleep 1
done
