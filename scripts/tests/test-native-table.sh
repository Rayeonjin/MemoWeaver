#!/bin/bash
# Tests run against synthetic tables, never actual WorkOS note data.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARCH="$(uname -m)"
  PLATFORM=(-sdk "$SDK" -target "${ARCH}-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
  PLATFORM=()
fi
TEMP="$(mktemp -d /tmp/memoryhome-native-table.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
"$SWIFTC" -swift-version 5 -Onone "${PLATFORM[@]}" \
  "$ROOT/WorkOSMac/PasteTableCore.swift" "$ROOT/Tests/TableConversionCoreSmoke.swift" \
  -o "$TEMP/TableConversionCoreSmoke"
"$TEMP/TableConversionCoreSmoke"
if [[ "$(uname -s)" == Darwin ]]; then
  "$SWIFTC" -swift-version 5 -Onone "${PLATFORM[@]}" -framework AppKit \
    "$ROOT/WorkOSMac/PasteTableCore.swift" "$ROOT/WorkOSMac/NativeTableConversion.swift" \
    "$ROOT/Tests/NativeTableSelectionSmoke.swift" -o "$TEMP/NativeTableSelectionSmoke"
  "$TEMP/NativeTableSelectionSmoke"
else
  echo 'SKIP: NSTextTable AppKit runtime test requires macOS (run this test on Mac)'
fi
bash "$ROOT/Tests/NativeTableIntegrationSmoke.sh"
