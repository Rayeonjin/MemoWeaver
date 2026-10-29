#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
bash "$ROOT/Tests/EditorVisibilityRegressionSmoke.sh"
bash "$ROOT/Tests/EditorWrapIntegrationSmoke.sh"
TEMP="$(mktemp -d /tmp/workos-editor-recovery.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARCH="$(uname -m)"
  "$SWIFTC" -swift-version 5 -parse-as-library -Onone -j 1 -sdk "$SDK" -target "${ARCH}-apple-macosx14.0" \
    -framework AppKit "$ROOT/Tests/EditorVisibleMacSmoke.swift" -o "$TEMP/EditorVisibleMacSmoke"
  "$TEMP/EditorVisibleMacSmoke"
else
  echo 'SKIP AppKit glyph test (requires macOS)' 
fi
printf 'PASS editor recovery checks (user data not accessed)\n'
