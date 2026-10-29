#!/bin/bash
# Cross-platform, Foundation-only syntax parser regression plus macOS bridge
# structure checks (no private notes, no real SQLite database).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/memoryhome-syntax.XXXXXXXX")"
trap 'rm -rf -- "$TEMP"' EXIT
PLATFORM=()
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARCH="$(uname -m)"
  PLATFORM=(-sdk "$SDK" -target "${ARCH}-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
fi
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library "${PLATFORM[@]}" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/WorkOSMac/MarkdownEditorHighlightCore.swift" \
  "$ROOT/Tests/MarkdownEditorHighlightSmoke.swift" -o "$TEMP/highlight-smoke"
"$TEMP/highlight-smoke"
grep -Fq 'override func drawBackground(in rect: NSRect)' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'manager.addTemporaryAttribute(.foregroundColor' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'if hasMarkedText() { syntaxRefreshAfterIME = true; return }' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'caretDidMove()' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'WorkOSLineNumberPainter.gutterWidth + 2' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
echo 'PASS editor integration hooks: paint-only caret line, temporary colors, Korean IME, preserved gutter'
