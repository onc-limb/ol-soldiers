#!/bin/bash
# scripts/inbox_write.sh - アトミックなメッセージ書き込み
# 使い方: inbox_write.sh <宛先agent_id> "<メッセージ>" <種別> <送信元>
set -euo pipefail

TARGET="$1"
MESSAGE="$2"
MSG_TYPE="${3:-general}"     # cmd_new / task_assigned / report_received / general
FROM="${4:-system}"

# プロジェクトの .ol-soldiers を探す
MA_DIR="$(pwd)/.ol-soldiers"
if [ ! -d "$MA_DIR" ]; then
    echo "[ERROR] .ol-soldiers/ が見つかりません。ols-start を先に実行してください。"
    exit 1
fi

INBOX_FILE="${MA_DIR}/queue/inbox/${TARGET}.yaml"
LOCK_DIR="${INBOX_FILE}.lock"

# mkdir による排他ロック（POSIX準拠、macOS互換）
acquire_lock() {
    local max_retries=50
    local i=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        i=$((i + 1))
        if [ "$i" -ge "$max_retries" ]; then
            echo "[ERROR] ロック取得に失敗しました: ${LOCK_DIR}" >&2
            exit 1
        fi
        sleep 0.1
    done
    trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
}

acquire_lock

cat >> "$INBOX_FILE" <<EOF
- timestamp: "$(date -Iseconds)"
  from: "${FROM}"
  type: "${MSG_TYPE}"
  message: "${MESSAGE}"
EOF

rmdir "$LOCK_DIR" 2>/dev/null
trap - EXIT
