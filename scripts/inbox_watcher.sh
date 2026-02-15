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
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# === エスカレーション機能 ===

# ISO 8601 timestamp を epoch 秒に変換
ts_to_epoch() {
    local ts="$1"
    # GNU date (-d オプション)
    date -d "$ts" "+%s" 2>/dev/null && return 0
    # macOS BSD date (-j -f オプション)
    local normalized
    normalized=$(printf '%s' "$ts" | sed 's/T/ /; s/\([-+][0-9][0-9]\):\([0-9][0-9]\)$/\1\2/')
    date -j -f "%Y-%m-%d %H:%M:%S%z" "$normalized" "+%s" 2>/dev/null && return 0
    echo "0"
}

# 応答チェック: エージェントが通知に反応したかを判定
# NOTIFICATION_EPOCH 以降に出力ファイルが更新されていれば「応答あり」と判定
check_response() {
    case "$AGENT_ID" in
        soldier*)
            # soldier: タスク YAML の status が "assigned" 以外に変化したか
            local task_file="${PROJECT_ROOT}/.ol-soldiers/queue/tasks/${AGENT_ID}.yaml"
            local status
            status=$(grep "^status:" "$task_file" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || true)
            [ "$status" != "assigned" ] && return 0
            ;;
        sergeant)
            # sergeant: tasks/*.yaml または dashboard.md が通知後に更新されたか
            local file_mtime
            for f in "${PROJECT_ROOT}/.ol-soldiers/queue/tasks"/*.yaml "${PROJECT_ROOT}/.ol-soldiers/dashboard.md"; do
                [ -f "$f" ] || continue
                file_mtime=$(stat -f %m "$f" 2>/dev/null || echo "0")
                if [ "$file_mtime" -gt "$NOTIFICATION_EPOCH" ]; then
                    return 0
                fi
            done
            ;;
        commander)
            # commander: commander_to_sergeant.yaml が通知後に更新されたか
            local cmd_file="${PROJECT_ROOT}/.ol-soldiers/queue/commander_to_sergeant.yaml"
            if [ -f "$cmd_file" ]; then
                local file_mtime
                file_mtime=$(stat -f %m "$cmd_file" 2>/dev/null || echo "0")
                if [ "$file_mtime" -gt "$NOTIFICATION_EPOCH" ]; then
                    return 0
                fi
            fi
            ;;
    esac
    return 1
}

# エスカレーション処理（バックグラウンドで実行）
run_escalation() {
    local nudge_msg="$1"

    # Commander/Sergeant は分析に時間がかかるためタイムアウトを延長
    local phase_a_wait=30
    local phase_b_wait=30
    case "$AGENT_ID" in
        commander|sergeant)
            phase_a_wait=90
            phase_b_wait=60
            ;;
    esac

    # Phase A: 待機後に再ナッジ
    sleep "$phase_a_wait"
    if check_response; then
        log "エスカレーション不要: 応答あり"
        return 0
    fi
    log "Phase A: 再ナッジ送信"
    printf '%s' "$nudge_msg" | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
    sleep 0.2
    printf '\r' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste

    # Phase B: さらに待機後に Escape + 再ナッジ
    sleep "$phase_b_wait"
    if check_response; then
        log "エスカレーション不要: Phase B 前に応答あり"
        return 0
    fi
    log "Phase B: Escape + 再ナッジ送信"
    printf '\x1b' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
    sleep 0.5
    printf '%s' "$nudge_msg" | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
    sleep 0.2
    printf '\r' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste

    # Phase C: さらに60秒後に escalation.sh 呼び出し
    sleep 60
    if check_response; then
        log "エスカレーション不要: Phase C 前に応答あり"
        return 0
    fi
    log "Phase C: escalation.sh を呼び出し"
    bash "${SCRIPT_DIR}/escalation.sh" "$AGENT_ID" "$PANE_ID" "$PROJECT_ROOT"
}

ESCALATION_PID=""
NOTIFICATION_EPOCH=0

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

    case "$LATEST_TYPE" in
        task_assigned|cmd_new)
            # アクション必須の種別: フルエスカレーション（Phase A→B→C）
            if [ -n "$ESCALATION_PID" ] && kill -0 "$ESCALATION_PID" 2>/dev/null; then
                kill "$ESCALATION_PID" 2>/dev/null || true
                wait "$ESCALATION_PID" 2>/dev/null || true
            fi
            NOTIFICATION_EPOCH=$(date "+%s")
            run_escalation "$NUDGE" &
            ESCALATION_PID=$!
            log "エスカレーション開始 (種別: ${LATEST_TYPE})"
            ;;
        *)
            # 情報通知の種別 (report_received, general 等): nudge のみ、エスカレーションなし
            log "エスカレーション不要 (種別: ${LATEST_TYPE}, nudge のみ)"
            ;;
    esac
done
