#!/bin/bash
# No user notes or SQLite DB accessed. The same Swift target as build.sh on macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
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
TEMP="$(mktemp -d /tmp/workos-preview.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
"$SWIFTC" -swift-version 5 -Onone "${PLATFORM[@]}" \
  "$ROOT/WorkOSMac/Models.swift" \
  "$ROOT/WorkOSMac/NotebookMembershipCore.swift" \
  "$ROOT/WorkOSMac/QuickCaptureCore.swift" \
  "$ROOT/WorkOSMac/WorkBlocks.swift" \
  "$ROOT/WorkOSMac/NotePreviewRules.swift" \
  "$ROOT/WorkOSMac/NoteDocuments.swift" "$ROOT/WorkOSMac/MemoWeaverAttachments.swift" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" "$ROOT/WorkOSMac/MarkdownCore.swift" "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" \
  "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift" \
  "$ROOT/Tests/NoteSidePreviewSmoke.swift" \
  -o "$TEMP/NoteSidePreviewSmoke"
"$TEMP/NoteSidePreviewSmoke"
# Historical 0.9.1 grep-only tests assume a 550ms debounce and two tabs;
# they cannot validate the current four-tab native workspace. v0.9.55's
# live preview/scene tests supersede those removed-source assertions.
echo 'PASS actual current Markdown preview renderer (Math/Mermaid/mindmap)'
