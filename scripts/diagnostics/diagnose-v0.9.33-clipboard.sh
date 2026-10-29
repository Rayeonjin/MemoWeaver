#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Run this on macOS after copying a screenshot to the clipboard.' >&2
  exit 1
fi
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-paste-diagnose.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -swift-version 5 -j 1 -parse-as-library -framework AppKit \
  "$ROOT/WorkOSMac/MemoWeaverAttachments.swift" \
  "$ROOT/WorkOSMac/MemoWeaverImageClipboard.swift" \
  "$ROOT/Tests/InspectCurrentPasteboardV0933.swift" -o "$TMP/mw-clipboard"
"$TMP/mw-clipboard"
