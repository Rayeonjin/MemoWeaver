#!/bin/bash
# v0.9.49 optical toolbar center and dynamic NSWindow minimum policy.
# No writes to an installed application, user preferences or data files.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then SWIFTC="$(xcrun --sdk macosx --find swiftc)"; fi
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0949.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MemoWeaverToolbarGeometry.swift" \
  "$ROOT/Tests/ToolbarMinimumV0949Smoke.swift" -o "$TMP/toolbar-minimum"
"$TMP/toolbar-minimum"
python3 - "$ROOT" <<'PYTEST'
from pathlib import Path
import plistlib, hashlib, re, sys
root=Path(sys.argv[1]); work=root/'WorkOSMac'
read=lambda name: (work/name).read_text()
plist=plistlib.loads((work/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier']) == ('0.9.49','82','com.local.workos.notes')
native=read('MemoWeaverNativeWindowChrome.swift'); geom=read('MemoWeaverToolbarGeometry.swift')
assert 'titleTextOrigin' in native and 'titleTextHeight' in native
assert 'view.frame = NSRect(x: floor(x), y: top' in native
assert 'window.contentMinSize = target' in native
assert 'NSEvent.pressedMouseButtons & 1 == 0' in native
assert 'window.screen?.visibleFrame.width' in native
assert '.frame(minWidth: 970' not in read('WorkOSApp.swift')
assert 'minimumContentWidth(' in geom
assert 'NSTrackingSeparatorToolbarItem(' not in native
assert 'insertItem(' not in native and 'removeItem(' not in native
assert 'canvas.separatorColor = split.dividerColor' in native
assert 'window.toolbarStyle = .unifiedCompact' in native
assert 'MemoWeaverToolbarItems.rightTabs' in native
# The release ZIP must validate on the USER'S Mac, without requiring a
# /mnt/data sibling directory from the build environment.
expected={
    'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
    'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
    'MemoWeaverPinnedSplitView.swift':'0a8c7a49d3510470bd6f42c658fd44290284ad1e6b060e80b3b19fe4f382819a',
    'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
    'MarkdownPlainEditor.swift':'26115ff0aa756af91518da60706b8765ff5f3123142ad425d6fc5b1726101fd7',
    'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
    'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796',
}
for name, known in expected.items():
    actual=hashlib.sha256((work/name).read_bytes()).hexdigest()
    assert actual==known, 'protected source changed: '+name
main=read('MainView.swift')
assert 'private func reserveWindowForPaneOpening' in main
assert 'reserveWindowForPaneOpening(list: true, right: effectiveRightPaneVisible)' in main
assert 'reserveWindowForPaneOpening(list: effectiveListVisible, right: true)' in main
assert 'reserveWindowForPaneOpening(list: noteListVisible, right: sidePaneVisible)' in main
assert 'window.setFrame(target, display: true, animate: false)' in native
assert 'MemoWeaverToolbarGeometry.expansionFrame(' in native
assert 'private var lastVisibility:' in native
assert 'if shouldExpand {' in native
assert 'static func expansionFrame(' in geom
install=(root/'install-v0.9.49.sh').read_text()
assert 'test-v0.9.49-toolbar-minimum.sh' in install and '"$ROOT/build.sh"' in install
for name in re.findall(r'^\s+(test-v[0-9.]+[^\s]+\.sh)',install,re.M):
    assert (root/name).is_file(), 'missing installer test: '+name
print('PASS v0.9.49 portable 7 SHA256 baselines, pre-open frame expansion, no tracking separator')
PYTEST
if [[ "$(uname -s)" == Darwin ]]; then
  "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library -framework AppKit \
    "$ROOT/WorkOSMac/MemoWeaverToolbarGeometry.swift" \
    "$ROOT/Tests/NativeWindowMinimumV0949Smoke.swift" -o "$TMP/window-minimum"
  "$TMP/window-minimum"
  "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library -framework AppKit -framework SwiftUI \
    "$ROOT/WorkOSMac/MemoWeaverCommands.swift" \
    "$ROOT/WorkOSMac/MemoWeaverToolbarGeometry.swift" \
    "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
    "$ROOT/Tests/NativeWindowV0943Smoke.swift" -o "$TMP/native-toolbar"
  "$TMP/native-toolbar"
else
  echo 'SKIP AppKit compile / native GUI (macOS required)'
fi
