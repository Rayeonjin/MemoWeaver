#!/bin/bash
# Tests foreground color contrast/selection rules against AppKit using a temporary binary.
# Does not open the user's notes database or modify the installed app.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
[[ "$(uname -s)" == Darwin ]] || { echo 'EditorInkSmoke needs macOS Apple Command Line Tools.' >&2; exit 1; }
export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
SWIFTC="$(xcrun --sdk macosx --find swiftc)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
TMP="$(mktemp -d /tmp/memoryhome-ink.XXXXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT
"$SWIFTC" -swift-version 5 -Onone -sdk "$SDK" -target "$(uname -m)-apple-macosx14.0" \
    -framework AppKit "$ROOT/WorkOSMac/EditorInk.swift" "$ROOT/Tests/EditorInkSmoke.swift" \
    -o "$TMP/EditorInkSmoke"
"$TMP/EditorInkSmoke"
"$SWIFTC" -swift-version 5 -Onone -sdk "$SDK" -target "$(uname -m)-apple-macosx14.0" \
    "$ROOT/WorkOSMac/RichHTMLColorStyles.swift" "$ROOT/Tests/HTMLColorStylesSmoke.swift" \
    -o "$TMP/HTMLColorStylesSmoke"
"$TMP/HTMLColorStylesSmoke"
"$ROOT/Tests/EditorInkIntegrationSmoke.sh"
