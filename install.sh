#!/bin/bash
# install.sh - 初回セットアップ
set -euo pipefail

echo "=== マルチエージェントシステム セットアップ ==="

# 1. 依存チェック
check_dependency() {
    if ! command -v "$1" &>/dev/null; then
        echo "[ERROR] $1 が見つかりません。インストールしてください。"
        echo "  $2"
        return 1
    fi
    echo "[OK] $1: $(command -v "$1")"
}

check_dependency tmux     "sudo apt install tmux  /  brew install tmux"
check_dependency claude   "https://code.claude.com からインストール"
check_dependency inotifywait "sudo apt install inotify-tools（Phase 2 で必要）" || true

# 2. グローバルディレクトリを配置
INSTALL_DIR="$HOME/.ol-soldiers"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -d "$INSTALL_DIR" ] && [ "${1:-}" != "--force" ]; then
    echo "[SKIP] ${INSTALL_DIR} は既に存在します。--force で上書き。"
else
    mkdir -p "$INSTALL_DIR"
    cp -r "$SCRIPT_DIR"/{commands,templates,lib} "$INSTALL_DIR/"
    # scripts/ が存在する場合のみコピー
    [ -d "$SCRIPT_DIR/scripts" ] && cp -r "$SCRIPT_DIR/scripts" "$INSTALL_DIR/" || true
    chmod +x "$INSTALL_DIR"/commands/*
    chmod +x "$INSTALL_DIR"/scripts/* 2>/dev/null || true
    echo "[OK] ${INSTALL_DIR} にインストールしました。"
fi

# 3. PATH への追加案内
if [[ ":$PATH:" != *":${INSTALL_DIR}/commands:"* ]]; then
    echo ""
    echo "以下を .bashrc または .zshrc に追加してください:"
    echo ""
    echo "  export PATH=\"\$HOME/.ol-soldiers/commands:\$PATH\""
    echo ""
fi

# 4. tmux 設定（マウス有効化）
TMUX_CONF="$HOME/.tmux.conf"
if ! grep -q "set -g mouse on" "$TMUX_CONF" 2>/dev/null; then
    echo "set -g mouse on" >> "$TMUX_CONF"
    echo "[OK] tmux マウス操作を有効化しました。"
fi

echo ""
echo "=== セットアップ完了 ==="
echo "使い方: プロジェクトディレクトリで ols-start を実行"
