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
check_response() {
    case "$AGENT_ID" in
        soldier*)
            # soldier: タスク YAML の status が "assigned" 以外に変化したか
            local task_file="${PROJECT_ROOT}/.ol-soldiers/queue/tasks/${AGENT_ID}.yaml"
            local status
            status=$(grep "^status:" "$task_file" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || true)
            [ "$status" != "assigned" ] && return 0
            ;;
        *)
            # commander/sergeant: inbox の最終 timestamp と現在時刻の差で判定
            local last_ts
            last_ts=$(grep "timestamp:" "$INBOX_FILE" | tail -1 | awk '{print $2}' | tr -d '"' || true)
            if [ -n "$last_ts" ]; then
                local last_epoch current_epoch diff
                last_epoch=$(ts_to_epoch "$last_ts")
                current_epoch=$(date "+%s")
                diff=$((current_epoch - last_epoch))
                # 25秒以内に inbox 更新あり → 応答あり
                [ "$diff" -lt 25 ] && return 0
            fi
            ;;
    esac
    return 1
}

# エスカレーション処理（バックグラウンドで実行）
run_escalation() {
    local nudge_msg="$1"

    # Phase A: 30秒後に再ナッジ
    sleep 30
    if check_response; then
        log "エスカレーション不要: 応答あり"
        return 0
    fi
    log "Phase A: 再ナッジ送信"
    printf '%s' "$nudge_msg" | wezterm cli send-text --pane-id "$PANE_ID" --no-paste
    sleep 0.2
    printf '\r' | wezterm cli send-text --pane-id "$PANE_ID" --no-paste

    # Phase B: さらに30秒後に Escape + 再ナッジ
    sleep 30
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

    # 前回のエスカレーションプロセスがあれば終了
    if [ -n "$ESCALATION_PID" ] && kill -0 "$ESCALATION_PID" 2>/dev/null; then
        kill "$ESCALATION_PID" 2>/dev/null || true
        wait "$ESCALATION_PID" 2>/dev/null || true
    fi

    # バックグラウンドでエスカレーション判定を開始
    run_escalation "$NUDGE" &
    ESCALATION_PID=$!
done
