#!/bin/bash
# Finder-style native AppKit toolbar, right-pane action persistence, plus
# the protected local note/image/pane data-path regression checks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
else
  SWIFTC="$(command -v swiftc)"
fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'CHECK'
import hashlib, plistlib, sys
from pathlib import Path
p=Path(sys.argv[1]); w=p/'WorkOSMac'
read=lambda name:(w/name).read_text()
main, chrome, app, palette=map(read,['MainView.swift','MemoWeaverNativeWindowChrome.swift','WorkOSApp.swift','MemoWeaverQuickSearchPalette.swift'])
info=plistlib.loads((w/'Info.plist').read_bytes())
assert (info['CFBundleShortVersionString'],info['CFBundleVersion'],info['CFBundleIdentifier']) == ('0.9.38','71','com.local.workos.notes')
assert 'ToolbarItemGroup' not in main and '.toolbar { nativeWindowToolbar }' not in main
assert 'NSToolbar(identifier: MemoWeaverToolbarItems.identifier)' in chrome
assert 'list, .flexibleSpace, paneTabs, .flexibleSpace, focus, newNote, right, search' in chrome
assert 'NSSearchToolbarItem(itemIdentifier: identifier)' in chrome
assert 'NSSegmentedControl(' in chrome and 'memoWeaverSelectRightPaneTab' in chrome
assert 'sideTab(.preview' not in main and 'selectedTab' in main
assert 'item.visibilityPriority = .user' in chrome
assert 'hasCurrentNote' in chrome and 'snapshot.isNotePage && snapshot.hasCurrentNote' in chrome
assert 'memoWeaverToggleRightPane' in chrome and 'memoWeaverCreateNewNote' in chrome
assert 'memoWeaverOpenQuickSearch' in chrome and 'initialQuery' in palette
assert 'window.titlebarAppearsTransparent = true' in chrome
assert 'window.toolbarStyle = .unifiedCompact' in chrome
assert 'MemoWeaverPinnedSplitView(' in main and 'fullHeightSidebarSurface' in main
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in main
# All fields and all main SQLite/image/input/pane sources must be byte-identical
# to the previous, Mac-confirmed stable version. No migrations are permitted.
expected = {'Storage.swift': 'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199', 'MemoWeaverAttachments.swift': 'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db', 'MemoWeaverPinnedSplitView.swift': '972e15b504a7ef371a22c8fa5b75d64bf2b1759c404dd7a40f8850c1b6f5302d', 'MemoWeaverPinnedPaneLayout.swift': '2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278', 'MarkdownPlainEditor.swift': '3e6d0bc50502f4a5923bd9053c0a1c7c274e85fa3eeaf012bf8216e48d9364db', 'MemoWeaverImageClipboard.swift': 'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29', 'MemoWeaverPasteSelection.swift': '770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796'}
for name, digest in expected.items():
    assert hashlib.sha256((w/name).read_bytes()).hexdigest()==digest, f'protected file changed: {name}'
print('PASS source: native trailing toolbar with persistent right-pane button; protected storage, image, pane files')
CHECK
if [[ "$(uname -s)" == Darwin ]]; then
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0938-native.XXXXXXXX")"
  trap 'rm -rf -- "$TMP"' EXIT
  "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    -framework AppKit -framework SwiftUI \
    "$ROOT/WorkOSMac/MemoWeaverCommands.swift" \
    "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
    "$ROOT/Tests/NativeWindowV0938Smoke.swift" -o "$TMP/native-test"
  "$TMP/native-test"
else
  echo 'SKIP real NSWindow execution: Linux. Run this script on a Mac.'
fi
