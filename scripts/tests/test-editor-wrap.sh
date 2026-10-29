#!/bin/bash
# Checks window-width reflow against synthetic content; no private notes loaded.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
bash "$ROOT/Tests/EditorWrapIntegrationSmoke.sh"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'SKIP native TextKit split-resize test (requires macOS)'
  exit 0
fi
export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
SWIFTC="$(xcrun --sdk macosx --find swiftc)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
TEMP="$(mktemp -d /tmp/workos-editor-wrap.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
"$SWIFTC" -swift-version 5 -parse-as-library -Onone -j 1 \
  -sdk "$SDK" -target "${ARCH}-apple-macosx14.0" \
  -framework AppKit \
  "$ROOT/WorkOSMac/EditorWrapViewport.swift" \
  "$ROOT/Tests/EditorWrapMacSmoke.swift" \
  -o "$TEMP/EditorWrapMacSmoke"
"$TEMP/EditorWrapMacSmoke"
