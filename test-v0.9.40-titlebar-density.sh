#!/bin/bash
# MemoWeaver v0.9.40 Build 73: full-height pane headers without a wasted toolbar row.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT/Tests/NativeWindowV0940Smoke.swift"
python3 - "$ROOT" <<'CHECK'
from pathlib import Path
import hashlib, plistlib, sys
r=Path(sys.argv[1]);w=r/'WorkOSMac'
src=lambda name:(w/name).read_text()
chrome=src('MemoWeaverNativeWindowChrome.swift')
main=src('MainView.swift')
editor=src('MemoWeaverEditorChrome.swift')
note=src('MarkdownNoteScreen.swift')
shared=src('MemoWeaverPaneFooter.swift')
split=src('MemoWeaverPinnedSplitView.swift')
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier'])==('0.9.40','73','com.local.workos.notes')
assert 'window.toolbar = nil' in chrome
assert 'window.styleMask.insert(.fullSizeContentView)' in chrome
assert 'window.titlebarAppearsTransparent = true' in chrome
assert 'NSToolbar(identifier:' not in chrome and 'NSTrackingSeparatorToolbarItem' not in chrome
assert '.ignoresSafeArea(.container, edges: isNotePage ? .top : [])' in main
assert 'MemoWeaverNativeWindowChrome()' in main
assert 'fullHeightSidebarSurface' not in main, 'Do not paint a simulated divider over a real split'
assert 'MemoWeaverTitlebarMetrics.railTopPadding : 9' in main
assert 'MemoWeaverTitlebarMetrics.listTitleLeadingClearance' in main
assert 'editorTitleLeadingClearance(' in editor and 'editorTitleLeadingClearance(' in main
assert 'private var listHeader' in main and 'memoWeaverCreateNewNote' in main
assert 'sideTab(.preview' in main and 'sideTab(.memory' in main and 'sideTab(.reference' in main
assert 'focusMode: focusModeEnabled' in main and 'focusMode: focusMode' in note
assert 'private var focusToggle' in editor and 'memoWeaverToggleFocusMode' in editor
first=editor[editor.index('HStack(spacing: 4) {'):editor.index('.frame(height: 30, alignment: .leading)')]
assert first.index('listToggle') < first.index('titleInput') < first.index('focusToggle') < first.index('auxiliaryToggle')
assert 'private var auxiliaryToggle' in editor and 'memoWeaverToggleRightPane' in editor
assert 'sidebar.right.fill' not in editor and 'sidebar.left.fill' not in editor
assert 'MemoWeaverPaneToggleGlyph(side: .right, isOpen: auxiliaryPaneVisible)' in editor
assert 'MemoWeaverPaneToggleGlyph' in shared and 'RoundedRectangle' in shared
assert 'selected: auxiliaryPaneVisible' in editor
assert 'if !listPaneVisible { newNoteButton }' in editor
assert 'MemoWeaverPinnedSplitView(' in main and 'memoWeaverToggleNoteList' in main
assert 'NSUserInterfaceItemIdentifier("MemoWeaver.notes.pinnedSplit")' in split
assert 'MemoWeaverEditorImageInput.read(board)' in src('MarkdownPlainEditor.swift')
# Stable paths and blobs must remain completely untouched.
expected={
'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
'MemoWeaverPinnedSplitView.swift':'0a8c7a49d3510470bd6f42c658fd44290284ad1e6b060e80b3b19fe4f382819a',
'MarkdownPlainEditor.swift':'3e6d0bc50502f4a5923bd9053c0a1c7c274e85fa3eeaf012bf8216e48d9364db',
'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796'
}
for name,digest in expected.items():
    actual=hashlib.sha256((w/name).read_bytes()).hexdigest()
    assert actual==digest, f'Protected implementation changed: {name} ({actual})'
print('PASS v0.9.40 source: reclaimed titlebar, focus in editor row, always-visible auxiliary glyph, 7 protected source hashes')
CHECK
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0940.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
"$SWIFTC" -swift-version 5 -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
  "$ROOT/Tests/PinnedPanesV0927Smoke.swift" -o "$TMP/pinned"
"$TMP/pinned"
"$SWIFTC" -swift-version 5 -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
  "$ROOT/Tests/PinnedPaneVisibilityV0929Smoke.swift" -o "$TMP/visibility"
"$TMP/visibility"
if [[ "$(uname -s)" == Darwin ]]; then
  "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    -framework AppKit -framework SwiftUI \
    "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
    "$ROOT/WorkOSMac/MemoWeaverPinnedSplitView.swift" \
    "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
    "$ROOT/Tests/NativeWindowV0940Smoke.swift" -o "$TMP/native-test"
  "$TMP/native-test"
else
  echo 'SKIP real NSWindow/full-size titlebar runtime (requires macOS).'
fi
