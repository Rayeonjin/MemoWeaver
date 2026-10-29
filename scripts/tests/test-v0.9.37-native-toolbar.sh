#!/bin/bash
# v0.9.37: ACTUAL SwiftUI ToolbarItems, full-height sidebar and compact list actions.
# No changes to installed data; Linux runs source checks, Mac runs an AppKit smoke test.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
else
  SWIFTC="$(command -v swiftc)"
fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'CHECK'
import sys, plistlib, hashlib
from pathlib import Path
root=Path(sys.argv[1]); w=root/'WorkOSMac'
read=lambda name:(w/name).read_text()
app,main,native=read('WorkOSApp.swift'),read('MainView.swift'),read('MemoWeaverNativeWindowChrome.swift')
editor,screen,footer=read('MemoWeaverEditorChrome.swift'),read('MarkdownNoteScreen.swift'),read('MemoWeaverPaneFooter.swift')
info=plistlib.loads((w/'Info.plist').read_bytes())
assert (info['CFBundleShortVersionString'],info['CFBundleVersion'],info['CFBundleIdentifier']) == ('0.9.37','70','com.local.workos.notes')
assert '.windowToolbarStyle(.unifiedCompact(showsTitle: false))' in app
assert '.toolbar { nativeWindowToolbar }' in main
assert '@ToolbarContentBuilder' in main and 'ToolbarItem(placement: .navigation)' in main and 'ToolbarItemGroup(placement: .automatic)' in main
for text in ('toggleNoteList()', 'model.newNoteFromShortcut()', 'toggleFocusMode', 'setSidePaneVisible(!sidePaneVisible)'):
    assert text in main, text
assert 'window.styleMask.insert(.fullSizeContentView)' in native
assert 'window.titlebarAppearsTransparent = true' in native
assert 'window.titlebarSeparatorStyle = .none' in native
assert 'window.toolbarStyle = .unifiedCompact' in native
assert 'NSToolbar(identifier:' not in native and 'window.toolbar = toolbar' not in native
assert 'MemoWeaverListVisibilityButton' not in editor and 'MemoWeaverTrailingWindowActions' not in editor
assert 'MemoWeaverWindowActions' not in main + editor + screen
assert not (w/'MemoWeaverWindowActions.swift').exists()
assert 'titleInput' in editor and 'pinButton' in editor and 'moreMenu' in editor
assert 'Button { showingListOptions.toggle() }' in main
assert 'Image(systemName: "ellipsis")' in main and '.frame(width: 28, height: 28)' in main
assert 'Toggle("간결한 목록", isOn: $compactRows)' in main and 'model.importArchivesDialog()' in main
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in screen and 'MemoWeaverWorkspaceHeaderMetrics.height' in main
assert 'static let height: CGFloat = 122' in footer
assert 'fullHeightSidebarSurface' in main and '.ignoresSafeArea(.container, edges: .top)' in main
assert 'MemoWeaverPinnedSplitView(' in main and 'model.editorCaretOffsets' in screen
# Critical user-confirmed functionality has not been rewritten.
expected = {'Storage.swift': 'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199', 'MemoWeaverAttachments.swift': 'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db', 'MemoWeaverPinnedSplitView.swift': '972e15b504a7ef371a22c8fa5b75d64bf2b1759c404dd7a40f8850c1b6f5302d', 'MemoWeaverPinnedPaneLayout.swift': '2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278', 'MarkdownPlainEditor.swift': '3e6d0bc50502f4a5923bd9053c0a1c7c274e85fa3eeaf012bf8216e48d9364db', 'MemoWeaverImageClipboard.swift': 'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29', 'MemoWeaverPasteSelection.swift': '770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796'}
for name, digest in expected.items():
    actual=hashlib.sha256((w/name).read_bytes()).hexdigest()
    assert actual==digest, f'{name}: protected functionality was modified'
print('PASS v0.9.37 source: real native toolbar items, fixed-size list options, aligned pane headers, protected user data and image paths')
CHECK
if [[ "$(uname -s)" == Darwin ]]; then
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0937-native.XXXXXXXX")"
  trap 'rm -rf -- "$TMP"' EXIT
  "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    -framework AppKit -framework SwiftUI \
    "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
    "$ROOT/Tests/NativeWindowV0937Smoke.swift" -o "$TMP/native-test"
  "$TMP/native-test"
else
  echo 'SKIP macOS NSWindow verification: this is Linux. Run --verify on a Mac.'
fi
