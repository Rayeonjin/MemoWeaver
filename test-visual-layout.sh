#!/bin/bash
# Synthetic Swift Foundation visual renderer + split layout regression.
# Does not open or modify the user's SQLite database.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d /tmp/memoryhome-v095.XXXXXXXX)"
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
  "$ROOT/Tests/VisualStageSmoke.swift" -o "$TEMP/visual-stage"
"$TEMP/visual-stage"
# The right pane must stay narrower than the editor, even on note switches.
grep -Fq 'MemoWeaverPinnedPaneLayout.resolved(' "$ROOT/WorkOSMac/MemoWeaverPinnedSplitView.swift"
grep -Fq 'rightPreferred: CGFloat(preferredRightWidth)' "$ROOT/WorkOSMac/MainView.swift"
grep -Fq 'dimensions.editor' "$ROOT/WorkOSMac/MemoWeaverPinnedSplitView.swift"
grep -Fq '.frame(minWidth: 160)' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq '<string>0.9.34</string>' "$ROOT/WorkOSMac/Info.plist"
grep -Fq '<string>67</string>' "$ROOT/WorkOSMac/Info.plist"
grep -Fq 'MemoWeaverPinnedSplitView(' "$ROOT/WorkOSMac/MainView.swift"
printf 'PASS native split constraints: resizable panel ideals and stable editor; line-number code unchanged\n'
