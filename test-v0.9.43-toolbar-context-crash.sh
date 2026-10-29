#!/bin/bash
# MemoWeaver v0.9.43 Build 76 UI crash / contextual editor source QA.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0943.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/Tests/MarkdownContextV0943Smoke.swift" -o "$TMP/context"
"$TMP/context"
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
  "$ROOT/Tests/PinnedPaneVisibilityV0929Smoke.swift" -o "$TMP/panes"
"$TMP/panes"
python3 - "$ROOT" <<'CHECK'
import hashlib, plistlib, sys
from pathlib import Path
r=Path(sys.argv[1]); w=r/'WorkOSMac'; read=lambda n:(w/n).read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier'])==('0.9.43','76','com.local.workos.notes')
chrome=read('MemoWeaverNativeWindowChrome.swift')
note=read('MarkdownNoteScreen.swift')
header=read('MemoWeaverEditorChrome.swift')
main=read('MainView.swift')
plain=read('MarkdownPlainEditor.swift')
metrics=read('MemoWeaverPaneFooter.swift')
assert 'NSToolbar(identifier:' in chrome and 'window.toolbar = toolbar' in chrome
assert 'NSTrackingSeparatorToolbarItem(' not in chrome, 'v0.9.42 crash: dynamic tracking separators forbidden'
assert 'toolbar.insertItem' not in chrome and 'toolbar.removeItem' not in chrome
assert 'static let workspace' in chrome and '[workspace]' in chrome
assert 'NSToolbarItem(itemIdentifier: identifier)' in chrome
assert 'NSWindow.didResizeNotification' in chrome
assert 'NSSplitView.didResizeSubviewsNotification' in chrome
assert 'registerSeparator' in chrome, 'Crash rationale should be documented'
assert 'window.backgroundColor = .windowBackgroundColor' in chrome
assert '"MemoWeaver"' in chrome and '"내 메모"' not in chrome
assert 'listOptions' not in chrome and 'showListOptions' not in chrome
assert 'model.importArchivesDialog()' in main and 'compactRows.toggle()' in main
assert 'static let height: CGFloat = 106' in metrics
assert 'metadataActions' in header and 'bookMenu' in header
assert 'ScrollView(.horizontal' not in note[note.index('private struct MarkdownAssistPalette:'):], 'Clipped contextual scroll must be removed'
assert 'ViewThatFits(in: .horizontal)' in note[note.index('private struct MarkdownAssistPalette:'):]
assert 'allToolsMenu' in note and 'groupedMenus' in note and '.controlSize(.mini)' in note
assert 'lastContextLine = -1' in plain and 'reportInitialCaret(in: editor)' in plain
assert 'MemoWeaverPinnedSplitView(' in main and 'memoWeaverToggleRightPane' in main
preserved = {
    'Storage.swift': 'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
    'MemoWeaverAttachments.swift': 'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
    'MemoWeaverPinnedSplitView.swift': '0a8c7a49d3510470bd6f42c658fd44290284ad1e6b060e80b3b19fe4f382819a',
    'MemoWeaverPinnedPaneLayout.swift': '2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
    'MemoWeaverImageClipboard.swift': 'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
    'MemoWeaverPasteSelection.swift': '770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796',
}
for file, digest in preserved.items():
    assert hashlib.sha256((w/file).read_bytes()).hexdigest() == digest, f'Protected file modified: {file}'
print('PASS v0.9.43: immutable NSToolbar, panel safe, colors, 3 header rows, contextual overflow, protected sources')
CHECK
if [[ "$(uname -s)" == Darwin ]]; then
    "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library -framework AppKit -framework SwiftUI \
        "$ROOT/WorkOSMac/MemoWeaverCommands.swift" \
        "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
        "$ROOT/Tests/NativeWindowV0943Smoke.swift" -o "$TMP/native"
    "$TMP/native"
else
    echo 'SKIP: AppKit native toolbar smoke / full app compile (Mac only)'
fi
