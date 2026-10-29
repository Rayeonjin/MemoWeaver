#!/bin/bash
# Tests do not access the actual WorkOS database or user clipboard.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# Keep the test target identical to build.sh. Swift 6.3 / macOS 26 can
# otherwise infer arm64-apple-macosx26.0 and fail to locate the stdlib.
SWIFT_PLATFORM=()
if [[ "$(uname -s)" == "Darwin" ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  [[ -d "$SDK" ]] || { echo '[WorkOS] macOS SDK not found' >&2; exit 1; }
  ARCH="$(uname -m)"
  case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; esac
  SWIFT_PLATFORM=(-sdk "$SDK" -target "${ARCH}-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
fi
TMP="$(mktemp -d /tmp/memoryhome-paste.XXXXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT
"$SWIFTC" -swift-version 5 -Onone "${SWIFT_PLATFORM[@]}" \
  "$ROOT/WorkOSMac/PasteTableCore.swift" "$ROOT/Tests/PasteTableSmoke.swift" \
  -o "$TMP/PasteTableSmoke"
"$TMP/PasteTableSmoke"
"$SWIFTC" -swift-version 5 -Onone "${SWIFT_PLATFORM[@]}" \
  "$ROOT/WorkOSMac/PasteRecoveryCore.swift" "$ROOT/Tests/PasteRecoverySmoke.swift" \
  -o "$TMP/PasteRecoverySmoke"
"$TMP/PasteRecoverySmoke"
if [[ "$(uname -s)" == "Darwin" ]]; then
  "$SWIFTC" -swift-version 5 -Onone "${SWIFT_PLATFORM[@]}" -framework AppKit \
    "$ROOT/WorkOSMac/EditorTypographyRules.swift" \
    "$ROOT/WorkOSMac/EditorTypography.swift" "$ROOT/Tests/PasteTypographySmoke.swift" \
    -o "$TMP/PasteTypographySmoke"
  "$TMP/PasteTypographySmoke"
else
  echo 'SKIP: AppKit imported-font rendering test requires macOS'
fi
bash "$ROOT/Tests/PasteIntegrationSmoke.sh"
