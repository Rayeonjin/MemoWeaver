#!/bin/bash
# Offline synthetic HTML/SVG smoke test. Never opens or writes the user's DB.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d /tmp/memoryhome-previewfix.XXXXXXXX)"
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
  "$ROOT/WorkOSMac/Models.swift" \
  "$ROOT/WorkOSMac/QuickCaptureCore.swift" \
  "$ROOT/WorkOSMac/WorkBlocks.swift" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/WorkOSMac/MarkdownCore.swift" "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" \
  "$ROOT/Tests/MarkdownPreviewFixSmoke.swift" -o "$TEMP/preview-test"
"$TEMP/preview-test"
# Guard a source-only, preview-only patch: no user-data format updates.
grep -Fq 'min-width:' "$ROOT/WorkOSMac/MarkdownCore.swift"
grep -Fq 'MermaidFlowchart.svg(code)' "$ROOT/WorkOSMac/MarkdownCore.swift"
grep -Fq 'baselineOffset = defaultBaselineOffset' "$ROOT/WorkOSMac/EditorLineNumberPainter.swift"
if grep -Fq 'emptyRowBaselineOffset(' "$ROOT/WorkOSMac/EditorLineNumberPainter.swift"; then
  echo 'FAIL: obsolete neighboring baseline compensation' >&2; exit 1
fi
grep -Fq 'storage.setAttributes(editor.typingAttributes,' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
