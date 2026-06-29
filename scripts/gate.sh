#!/usr/bin/env bash
# Status 提交门禁（CLAUDE.md §9）：swiftlint + swiftformat --lint + swift build + swift test
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▶ swiftlint"
swiftlint

echo "▶ swiftformat --lint"
swiftformat --lint .

echo "▶ swift build"
swift build

echo "▶ swift test"
swift test

echo "✅ all gates passed"
