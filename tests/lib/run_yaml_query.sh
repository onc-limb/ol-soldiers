#!/bin/bash
# tests/lib/run_yaml_query.sh - yaml_query.mjs を NODE_PATH 設定付きで起動するラッパ
#
# Why: takt 同梱の yaml パッケージは /opt/homebrew/lib/node_modules/takt/node_modules にある。
# NODE_PATH を明示的に指定しないと require/import が解決できない。

set -u

TAKT_NODE_MODULES="/opt/homebrew/lib/node_modules/takt/node_modules"

if [[ ! -d "$TAKT_NODE_MODULES" ]]; then
    echo "takt node_modules not found at: $TAKT_NODE_MODULES" >&2
    echo "install takt or update TAKT_NODE_MODULES path in this script" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_PATH="$TAKT_NODE_MODULES" node "$SCRIPT_DIR/yaml_query.mjs" "$@"
