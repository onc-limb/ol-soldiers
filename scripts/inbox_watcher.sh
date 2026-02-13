#!/bin/bash
# scripts/inbox_watcher.sh - ファイル変更を監視してエージェントを起こす
# 使い方: inbox_watcher.sh <agent_id> <wezterm_pane_id> <project_root>
set -euo pipefail

AGENT_ID="$1"
PANE_ID="$2"
PROJECT_ROOT="$3"
INBOX_FILE="${PROJECT_ROOT}/.ol-soldiers/queue/inbox/${AGENT_ID}.yaml"
LOG_FILE="${PROJECT_ROOT}/.ol-soldiers/logs/watcher.log"
FSWATCH_TIMEOUT=30

log() {
    echo "[$(date '+%H:%M:%S')] [watcher:${AGENT_ID}] $*" >> "$LOG_FILE"
}

# fswatch でイベント駆動監視し、タイムアウト時は stat で mtime フォールバック
wait_for_change() {
    local file="$1"
    local prev_mtime
    prev_mtime=$(stat -f %m "$file" 2>/dev/null || echo "0")
    while true; do
        # fswatch で即時検知を試みる（タイムアウト付き）
        timeout "$FSWATCH_TIMEOUT" fswatch -1 "$file" >/dev/null 2>&1 || true
        # fswatch が検知 or タイムアウト → stat で実際に変更があったか確認
        local curr_mtime
        curr_mtime=$(stat -f %m "$file" 2>/dev/null || echo "0")
        if [ "$curr_mtime" != "$prev_mtime" ]; then
            return
        fi
    done
}

touch "$INBOX_FILE"
log "監視開始: ${INBOX_FILE} (fswatch + stat fallback, timeout: ${FSWATCH_TIMEOUT}s)"

while true; do
    wait_for_change "$INBOX_FILE"

    log "変更検知"

    # 最新メッセージの type を読み取る（grep が空でも pipefail でクラッシュしないよう || true）
    LATEST_TYPE=$(tail -5 "$INBOX_FILE" | grep "type:" | tail -1 | awk '{print $2}' | tr -d '"' || true)

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

    # WezTerm CLI で通知送信（テキストとEnterを分離送信）
    printf '%s' "$NUDGE" | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
    sleep 0.2
    printf '\r' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
    log "通知送信: ${NUDGE}"

    # 連続イベントのデバウンス（1秒待つ）
    sleep 1
done
