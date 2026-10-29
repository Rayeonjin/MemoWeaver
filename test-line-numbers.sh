#!/bin/bash
# Pure core checks everywhere + AppKit geometry on Mac. Never touches user DB.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
bash "$ROOT/Tests/EditorLineNumberPaintIntegrationSmoke.sh"
bash "$ROOT/Tests/EditorWrapIntegrationSmoke.sh"
TEMP="$(mktemp -d /tmp/workos-line-number.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARCH="$(uname -m)"
  COMMON=(-swift-version 5 -parse-as-library -Onone -j 1 -sdk "$SDK" -target "${ARCH}-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
  COMMON=(-swift-version 5 -parse-as-library -Onone -j 1)
fi
"$SWIFTC" "${COMMON[@]}" "$ROOT/WorkOSMac/EditorLineNumberRules.swift" \
  "$ROOT/Tests/EditorLineNumberSmoke.swift" -o "$TEMP/EditorLineNumberSmoke"
"$TEMP/EditorLineNumberSmoke"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'SKIP native text painting (requires macOS AppKit)'
  exit 0
fi
"$SWIFTC" "${COMMON[@]}" -framework AppKit -framework CoreText \
  "$ROOT/WorkOSMac/EditorLineNumberRules.swift" \
  "$ROOT/WorkOSMac/EditorLineNumberPainter.swift" \
  "$ROOT/WorkOSMac/EditorLineNumberCanvas.swift" \
  "$ROOT/WorkOSMac/EditorWrapViewport.swift" \
  "$ROOT/Tests/EditorLineNumberPaintMacSmoke.swift" \
  -o "$TEMP/EditorLineNumberPaintMacSmoke"
"$TEMP/EditorLineNumberPaintMacSmoke"

# Exact Markdown layout regression, including consecutive empty lines.
"$SWIFTC" "${COMMON[@]}" -framework AppKit -framework CoreText \
  "$ROOT/WorkOSMac/EditorLineNumberRules.swift" \
  "$ROOT/WorkOSMac/EditorLineNumberPainter.swift" \
  "$ROOT/WorkOSMac/EditorLineNumberCanvas.swift" \
  "$ROOT/WorkOSMac/EditorWrapViewport.swift" \
  "$ROOT/Tests/EditorLineNumberBlankLineMacSmoke.swift" \
  -o "$TEMP/EditorLineNumberBlankLineMacSmoke"
"$TEMP/EditorLineNumberBlankLineMacSmoke"

# Regression for LF-only vs spaces/tabs with 17pt/20pt Markdown fonts.
"$SWIFTC" "${COMMON[@]}" -framework AppKit -framework CoreText \
  "$ROOT/WorkOSMac/EditorLineNumberRules.swift" \
  "$ROOT/WorkOSMac/EditorLineNumberPainter.swift" \
  "$ROOT/WorkOSMac/EditorLineNumberCanvas.swift" \
  "$ROOT/WorkOSMac/EditorWrapViewport.swift" \
  "$ROOT/Tests/EditorLineNumberWhitespaceMacSmoke.swift" \
  -o "$TEMP/EditorLineNumberWhitespaceMacSmoke"
"$TEMP/EditorLineNumberWhitespaceMacSmoke"
