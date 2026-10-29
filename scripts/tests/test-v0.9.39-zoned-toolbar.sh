#!/bin/bash
# Four-zone native titlebar and opposite-corner editor-title toggles.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'CHECK'
from pathlib import Path
import hashlib, plistlib, sys
r=Path(sys.argv[1]);w=r/'WorkOSMac'
source=lambda n:(w/n).read_text()
chrome=source('MemoWeaverNativeWindowChrome.swift')
editor=source('MemoWeaverEditorChrome.swift')
main=source('MainView.swift')
note=source('MarkdownNoteScreen.swift')
split=source('MemoWeaverPinnedSplitView.swift')
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier'])==('0.9.39','72','com.local.workos.notes')
assert 'NSTrackingSeparatorToolbarItem(' in chrome
assert 'split.identifier?.rawValue == "MemoWeaver.notes.pinnedSplit"' in chrome
assert 'NSUserInterfaceItemIdentifier("MemoWeaver.notes.pinnedSplit")' in split
assert 'snapshot.listVisible ? 1 : 0' in chrome
assert 'paneTabs' not in chrome and 'NSSegmentedControl' not in chrome
assert 'memoWeaverToggleNoteList' not in chrome and 'memoWeaverToggleRightPane' not in chrome
assert 'MemoWeaverToolbarItems.rightBoundary' in chrome
assert 'Button {' in editor and 'memoWeaverToggleNoteList' in editor and 'memoWeaverToggleRightPane' in editor
assert editor.index('listToggle',editor.index('HStack(spacing: 4)')) < editor.index('titleInput',editor.index('HStack(spacing: 4)'))
assert editor.index('auxiliaryToggle',editor.index('HStack(spacing: 4)')) > editor.index('Spacer(minLength: 4)',editor.index('HStack(spacing: 4)'))
assert 'auxiliaryPaneVisible: effectiveRightPaneVisible' in main and 'listPaneVisible: effectiveListVisible' in main
assert 'sideTab(.preview' in main and 'sideTab(.memory' in main and 'sideTab(.reference' in main
assert 'Text(paneTitle(selectedTab))' in main
assert 'MemoWeaverPinnedSplitView(' in main and 'fullHeightSidebarSurface' in main
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in main
assert 'MemoWeaverEditorImageInput.read(board)' in source('MarkdownPlainEditor.swift')
# Leave the proven database, attachment and clipboard input implementations byte-for-byte intact.
expected={
'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
'MarkdownPlainEditor.swift':'3e6d0bc50502f4a5923bd9053c0a1c7c274e85fa3eeaf012bf8216e48d9364db',
'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796'
}
for name,digest in expected.items():
    assert hashlib.sha256((w/name).read_bytes()).hexdigest()==digest,f'Protected source changed: {name}'
print('PASS zoned toolbar source: native tracking; title toggles at opposite corners; tabs inside right pane; protected persistence')
CHECK
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0939.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
"$SWIFTC" -swift-version 5 -j 1 -parse-as-library   "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift"   "$ROOT/Tests/PinnedPanesV0927Smoke.swift" -o "$TMP/pinned"
"$TMP/pinned"
"$SWIFTC" -swift-version 5 -j 1 -parse-as-library   "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift"   "$ROOT/Tests/PinnedPaneVisibilityV0929Smoke.swift" -o "$TMP/visibility"
"$TMP/visibility"
if [[ "$(uname -s)" == Darwin ]]; then
  "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library     -framework AppKit -framework SwiftUI     "$ROOT/WorkOSMac/MemoWeaverCommands.swift"     "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift"     "$ROOT/WorkOSMac/MemoWeaverPinnedSplitView.swift"     "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift"     "$ROOT/Tests/NativeWindowV0939Smoke.swift" -o "$TMP/native-test"
  "$TMP/native-test"
else
  echo 'SKIP real NSWindow/NSTrackingSeparatorToolbarItem runtime: requires macOS.'
fi
