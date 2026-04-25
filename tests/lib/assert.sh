#!/bin/bash
# tests/lib/assert.sh - 軽量テスト支援関数
#
# Why: ol-soldiers プロジェクトには既存のテスト基盤がない。
# takt ワークフロー (YAML + Markdown) の検証は構造アサーションが中心なので、
# bash + node (takt 同梱の yaml ライブラリ) を組み合わせた最小の支援関数で足りる。

set -u

# 呼び出し元が source する前提で、状態はグローバル変数に保持する
TEST_PASS_COUNT=0
TEST_FAIL_COUNT=0
TEST_CURRENT_NAME=""
TEST_FAILURES=()

test_start() {
    TEST_CURRENT_NAME="$1"
    printf '  ▶ %s\n' "$TEST_CURRENT_NAME"
}

_record_pass() {
    TEST_PASS_COUNT=$((TEST_PASS_COUNT + 1))
}

_record_fail() {
    local msg="$1"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT + 1))
    TEST_FAILURES+=("[$TEST_CURRENT_NAME] $msg")
    printf '    ✗ %s\n' "$msg"
}

assert_file_exists() {
    local path="$1"
    if [[ -f "$path" ]]; then
        _record_pass
    else
        _record_fail "file not found: $path"
    fi
}

assert_file_missing() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        _record_pass
    else
        _record_fail "file should not exist: $path"
    fi
}

assert_contains() {
    local path="$1"
    local pattern="$2"
    local description="${3:-$pattern}"
    if [[ ! -f "$path" ]]; then
        _record_fail "cannot check '$description': file missing: $path"
        return
    fi
    if grep -qE "$pattern" "$path"; then
        _record_pass
    else
        _record_fail "$path: missing $description"
    fi
}

assert_not_contains() {
    local path="$1"
    local pattern="$2"
    local description="${3:-$pattern}"
    if [[ ! -f "$path" ]]; then
        _record_fail "cannot check '$description': file missing: $path"
        return
    fi
    if grep -qE "$pattern" "$path"; then
        _record_fail "$path: should not contain $description"
    else
        _record_pass
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local description="$3"
    if [[ "$expected" == "$actual" ]]; then
        _record_pass
    else
        _record_fail "$description: expected '$expected', got '$actual'"
    fi
}

assert_command_succeeds() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        _record_pass
    else
        _record_fail "$description: command failed: $*"
    fi
}

assert_command_fails() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        _record_fail "$description: command unexpectedly succeeded: $*"
    else
        _record_pass
    fi
}

print_summary() {
    printf '\n=== Summary ===\n'
    printf '  passed: %d\n' "$TEST_PASS_COUNT"
    printf '  failed: %d\n' "$TEST_FAIL_COUNT"
    if (( TEST_FAIL_COUNT > 0 )); then
        printf '\nFailures:\n'
        for failure in "${TEST_FAILURES[@]}"; do
            printf '  - %s\n' "$failure"
        done
        return 1
    fi
    return 0
}
