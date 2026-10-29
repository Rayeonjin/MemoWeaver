#!/bin/bash
# MemoWeaver v0.9.41 Build 74 -- native toolbar zoning regression.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT/Tests/NativeWindowV0941Smoke.swift"
python3 - "$ROOT" <<'CHECK'
import hashlib, plistlib, sys
from pathlib import Path
r=Path(sys.argv[1]); w=r/'WorkOSMac'
read=lambda n:(w/n).read_text()
chrome=read('MemoWeaverNativeWindowChrome.swift')
main=read('MainView.swift')
editor=read('MemoWeaverEditorChrome.swift')
note=read('MarkdownNoteScreen.swift')
metrics=read('MemoWeaverPaneFooter.swift')
commands=read('MemoWeaverCommands.swift')
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier']) == ('0.9.41','74','com.local.workos.notes')
assert 'NSToolbar(identifier:' in chrome and 'window.toolbar = toolbar' in chrome
assert 'NSTrackingSeparatorToolbarItem(' in chrome
assert 'split.identifier?.rawValue == "MemoWeaver.notes.pinnedSplit"' in chrome
assert 'MemoWeaverToolbarItems.listBoundary' in chrome and 'MemoWeaverToolbarItems.rightBoundary' in chrome
assert 'items += [listToggle, editorTitle, .flexibleSpace]' in chrome
assert 'items += [pin, more, focus, rightToggle]' in chrome
assert 'if !state.listVisible { items.append(newNote) }' in chrome
assert 'if state.rightVisible {' in chrome and 'items.append(rightTabs)' in chrome
assert 'window.toolbar = nil' not in chrome
assert 'MemoWeaverNativeWindowChrome(snapshot: nativeToolbarSnapshot)' in main
assert '.ignoresSafeArea(.container, edges: isNotePage ? .top : [])' not in main
assert 'MemoWeaverTitlebarMetrics' not in main and 'MemoWeaverTitlebarMetrics' not in editor
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in main and 'MemoWeaverWorkspaceHeaderMetrics.height' in note
assert 'static let height: CGFloat = 94' in metrics
assert 'sideTab(.preview' not in main, 'Auxiliary tabs must only be in native auxiliary toolbar zone'
assert 'memoWeaverNativeEditorCommand' in commands and 'memoWeaverNativeEditorCommand' in note
assert 'case "title":' in note and 'case "pin": pinned.toggle()' in note
for a in ('details','trash','restore','checkpoint','history','memory','exportMarkdown','exportHTML','exportPDF'):
    assert f'case "{a}"' in note, f'Missing native toolbar route: {a}'
assert 'MemoWeaverEditorHeader(' in note
assert 'ViewThatFits(in: .horizontal)' in editor and 'MemoWeaverInsertToolbar' in note
assert 'NSImage(size: NSSize(width: 18, height: 16)' in chrome, 'Pane glyph must not disappear with SF Symbol fallback'
assert 'private var nativeToolbarSnapshot' in main
assert 'MemoWeaverPinnedSplitView(' in main and 'memoWeaverToggleRightPane' in main
assert 'NSUserInterfaceItemIdentifier("MemoWeaver.notes.pinnedSplit")' in read('MemoWeaverPinnedSplitView.swift')
# Preserve the seven validated storage/editor/pane implementation files, byte for byte.
expected={
'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
'MemoWeaverPinnedSplitView.swift':'0a8c7a49d3510470bd6f42c658fd44290284ad1e6b060e80b3b19fe4f382819a',
'MarkdownPlainEditor.swift':'3e6d0bc50502f4a5923bd9053c0a1c7c274e85fa3eeaf012bf8216e48d9364db',
'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796'
}
for n, expected_hash in expected.items():
    assert hashlib.sha256((w/n).read_bytes()).hexdigest()==expected_hash, f'Protected source changed: {n}'
print('PASS v0.9.41: true native toolbar, 4 split orders, no content duplicate title, routed menu, 7 protected hashes')
CHECK
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0941.XXXXXXXX")"
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
    "$ROOT/WorkOSMac/MemoWeaverCommands.swift" \
    "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
    "$ROOT/Tests/NativeWindowV0941Smoke.swift" -o "$TMP/native-smoke"
  "$TMP/native-smoke"
else
  echo 'SKIP: AppKit NSWindow/NSToolbar compile and runtime (Mac required).'
fi
