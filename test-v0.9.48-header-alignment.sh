#!/bin/bash
# MemoWeaver v0.9.48: isolated header contracts and Foundation-only geometry.
# No installed app, SQLite, attachments, or user preferences are changed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then SWIFTC="$(xcrun --sdk macosx --find swiftc)"; fi
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0948.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    "$ROOT/WorkOSMac/MemoWeaverToolbarGeometry.swift" \
    "$ROOT/Tests/ToolbarGeometryV0948Smoke.swift" -o "$TMP/toolbar-geometry"
"$TMP/toolbar-geometry"
python3 - "$ROOT" <<'PYTEST'
from pathlib import Path
import hashlib,plistlib,re,sys
root=Path(sys.argv[1]); work=root/'WorkOSMac'
read=lambda name:(work/name).read_text()
plist=plistlib.loads((work/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier']) == ('0.9.48','81','com.local.workos.notes')
native=read('MemoWeaverNativeWindowChrome.swift')
geo=read('MemoWeaverToolbarGeometry.swift')
# Ensure the rail/titlebar boundary view and the native registration crash path
# are absent at source level, not merely hidden.
assert 'class MemoWeaverTitlebarRailRule' not in native
assert 'titlebarRailRule' not in native
assert 'ensureTitlebarRailRule' not in native
assert 'updateTitlebarRailRule' not in native
assert 'NSTrackingSeparatorToolbarItem(' not in native
assert 'insertItem(' not in native and 'removeItem(' not in native
assert 'static func order(_ state: MemoWeaverToolbarSnapshot)' in native
assert '[workspace]' in native
# Read native color, thickness, and absolute X coordinates from NSSplitView.
assert 'canvas.separatorColor = split.dividerColor' in native
assert 'canvas.separatorThickness = split.dividerThickness' in native
assert 'canvas.separatorXs = MemoWeaverToolbarGeometry.dividerOrigins(' in native
assert 'viewX(children[1].frame.minX)' in native
assert 'viewX(children[expected - 1].frame.minX)' in native
assert 'canvas.separatorXs = []' in native
assert 'window?.backingScaleFactor' in native
assert 'separatorColor.setFill()' in native
# No more 20pt title fields alongside 28pt icons; both share one center.
assert 'MemoWeaverToolbarGeometry.verticalOrigin' in native
assert 'MemoWeaverToolbarGeometry.controlHeight' in native
assert 'let height: CGFloat = isText ? 20 : 28' not in native
assert 'text.controlSize = .regular' in native
assert 'label.controlSize = .regular' in native
assert 'button.controlSize = .regular' in native
assert 'tabs.controlSize = .regular' in native
assert 'controlHeight: CGFloat = 28' in geo
assert 'canvasHeight: CGFloat = 34' in geo
# Existing data paths and rendering machinery remain byte-for-byte identical.
protected={
 'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
 'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
 'MemoWeaverPinnedSplitView.swift':'0a8c7a49d3510470bd6f42c658fd44290284ad1e6b060e80b3b19fe4f382819a',
 'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
 'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
 'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796',
 'MarkdownPlainEditor.swift':'26115ff0aa756af91518da60706b8765ff5f3123142ad425d6fc5b1726101fd7',
}
for name, expected in protected.items():
    assert hashlib.sha256((work/name).read_bytes()).hexdigest()==expected, 'changed protected file '+name
# Ensure source delta is limited to the header plus the harmless MainView comment.
previous=Path('/mnt/data/MemoWeaver_Mac_v0.9.47_CLT')
if previous.is_dir():
    changed=[p.name for p in work.glob('*.swift') if (previous/'WorkOSMac'/p.name).exists()
             and p.read_bytes()!=(previous/'WorkOSMac'/p.name).read_bytes()]
    assert sorted(changed)==['MainView.swift','MemoWeaverNativeWindowChrome.swift'], changed
install=(root/'install-v0.9.48.sh').read_text()
assert 'test-v0.9.48-header-alignment.sh' in install and '"$ROOT/build.sh"' in install
for name in re.findall(r'^\s+(test-v[0-9.]+[^\s]+\.sh)', install, re.M):
    assert (root/name).is_file(), 'missing installer test '+name
print('PASS v0.9.48: no titlebar rail rule, native divider color/X, uniform control line, protected 7 files')
PYTEST
if [[ "$(uname -s)" == Darwin ]]; then
    "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
        -framework AppKit -framework SwiftUI \
        "$ROOT/WorkOSMac/MemoWeaverCommands.swift" \
        "$ROOT/WorkOSMac/MemoWeaverToolbarGeometry.swift" \
        "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
        "$ROOT/Tests/NativeWindowV0943Smoke.swift" -o "$TMP/native"
    "$TMP/native"
else
    echo 'SKIP AppKit/SwiftUI compile and real GUI (requires macOS)'
fi
