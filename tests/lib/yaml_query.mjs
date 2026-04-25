#!/usr/bin/env node
// tests/lib/yaml_query.mjs - takt 同梱の yaml パーサを使った軽量クエリ
//
// Why: ol-soldiers プロジェクトに pyyaml / js-yaml 等の YAML ライブラリがインストールされて
// いないため、takt (/opt/homebrew/lib/node_modules/takt) に同梱された yaml パッケージを
// NODE_PATH 経由で借りる。外部依存を増やさずにテストを走らせる最短ルート。
//
// 使い方:
//   node yaml_query.mjs <yaml-file> <jq-like-path>
//   例: node yaml_query.mjs workflow.yaml .name
//   例: node yaml_query.mjs workflow.yaml .steps[].name
//   例: node yaml_query.mjs workflow.yaml '.steps[] | select(.name == "execute") | .team_leader.max_parts'
//
// 出力は 1 行 1 値。存在しないパスは空文字列ではなく exit code 3 で返す。

import { readFileSync } from 'node:fs';
// Why: Node.js ESM は NODE_PATH を無視する。takt 同梱の yaml パッケージを直接パス指定で読む。
// TAKT_YAML_MODULE 環境変数で上書き可能にし、takt のインストール先が変わっても対応できるようにする。
const yamlModulePath = process.env.TAKT_YAML_MODULE
    ?? '/opt/homebrew/lib/node_modules/takt/node_modules/yaml/dist/index.js';
const { parse: parseYaml } = await import(yamlModulePath);

const [, , filePath, query] = process.argv;
if (!filePath || !query) {
    console.error('usage: yaml_query.mjs <yaml-file> <query>');
    process.exit(2);
}

let root;
try {
    root = parseYaml(readFileSync(filePath, 'utf8'));
} catch (err) {
    console.error(`parse error: ${err.message}`);
    process.exit(2);
}

function applySegment(values, segment) {
    const result = [];
    for (const value of values) {
        if (value === undefined || value === null) continue;
        if (segment === '[]') {
            if (Array.isArray(value)) result.push(...value);
            continue;
        }
        const selectMatch = segment.match(/^select\(\.([a-zA-Z_][\w]*)\s*==\s*"([^"]*)"\)$/);
        if (selectMatch) {
            const [, key, expected] = selectMatch;
            if (value && typeof value === 'object' && value[key] === expected) {
                result.push(value);
            }
            continue;
        }
        const indexMatch = segment.match(/^([a-zA-Z_][\w-]*)\[(\d+)\]$/);
        if (indexMatch) {
            const [, key, idx] = indexMatch;
            const arr = value[key];
            if (Array.isArray(arr)) {
                const item = arr[Number(idx)];
                if (item !== undefined) result.push(item);
            }
            continue;
        }
        if (/^[a-zA-Z_][\w-]*$/.test(segment)) {
            if (Object.prototype.hasOwnProperty.call(value, segment)) {
                result.push(value[segment]);
            }
            continue;
        }
        console.error(`unsupported segment: ${segment}`);
        process.exit(2);
    }
    return result;
}

function runQuery(root, query) {
    const stages = query.split('|').map((stage) => stage.trim()).filter((stage) => stage.length > 0);
    let current = [root];
    for (const stage of stages) {
        const body = stage.startsWith('.') ? stage.slice(1) : stage;
        if (body === '' || body === '.') continue;
        if (body.startsWith('select(')) {
            current = applySegment(current, body);
            continue;
        }
        const segments = [];
        let buf = '';
        let inBracket = false;
        for (const ch of body) {
            if (ch === '[') { inBracket = true; buf += ch; continue; }
            if (ch === ']') { inBracket = false; buf += ch; continue; }
            if (ch === '.' && !inBracket) {
                if (buf) { segments.push(buf); buf = ''; }
                continue;
            }
            buf += ch;
        }
        if (buf) segments.push(buf);
        for (const raw of segments) {
            const expanded = raw.endsWith('[]')
                ? [raw.slice(0, -2), '[]']
                : [raw];
            for (const seg of expanded) {
                current = applySegment(current, seg);
            }
        }
    }
    return current;
}

const values = runQuery(root, query);
if (values.length === 0) {
    process.exit(3);
}
for (const value of values) {
    if (value === null) {
        console.log('null');
    } else if (typeof value === 'object') {
        console.log(JSON.stringify(value));
    } else {
        console.log(String(value));
    }
}
