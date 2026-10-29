#!/bin/bash
# v0.9.45: visual chrome source contracts and Foundation/AppKit regression.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then SWIFTC="$(xcrun --sdk macosx --find swiftc)"; fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0945.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
for pair in     'MarkdownSlashPaletteV0944Smoke:caption'     'MarkdownContextV0943Smoke:context'     'MarkdownAssistCatalogV0945Smoke:catalog'; do
    src="${pair%%:*}"; bin="${pair##*:}"
    "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library         "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" "$ROOT/Tests/$src.swift" -o "$TMP/$bin"
    "$TMP/$bin"
done
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library     "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift"     "$ROOT/Tests/PinnedPaneVisibilityV0929Smoke.swift" -o "$TMP/panes"
"$TMP/panes"
python3 - "$ROOT" <<'CHECK'
from pathlib import Path
import hashlib, plistlib, sys, re
r=Path(sys.argv[1]); w=r/'WorkOSMac'
read=lambda name:(w/name).read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier']) == ('0.9.45','78','com.local.workos.notes')
chrome=read('MemoWeaverNativeWindowChrome.swift')
assert 'NSTrackingSeparatorToolbarItem(' not in chrome
assert 'insertItem(' not in chrome and 'removeItem(' not in chrome
assert 'window.toolbar = toolbar' in chrome
assert 'titlebarAppearsTransparent = false' in chrome
assert 'verticalRules' not in chrome and 'NSColor.separatorColor.withAlphaComponent' not in chrome
assert 'let height: CGFloat = 28' in chrome
assert 'label.font = .systemFont(ofSize: 13' in chrome
assert 'text.font = .systemFont(ofSize: 13' in chrome
main=read('MainView.swift')
rail=main.split('private var activityRail: some View {',1)[1].split('private var railStorageNeedsAttention:',1)[0]
assert '.frame(width: 52, height: MemoWeaverWorkspaceHeaderMetrics.height' in rail
assert '.background(Color(nsColor: .windowBackgroundColor))' in rail
assert 'Rectangle()' in rail and '.overlay(alignment: .bottom)' in rail
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in main
ctx=read('MarkdownNoteScreen.swift')
assert '.font(.system(size: 13, weight: .medium))' in ctx.split('private struct MarkdownAssistPalette: View')[1]
assert '.controlSize(.regular)' in ctx.split('private struct MarkdownAssistPalette: View')[1]
assert '.controlSize(.mini)' not in ctx.split('private struct MarkdownAssistPalette: View')[1]
# Only UI/content-insertion tools may change. Preserve proven data and
# panel sizing, clipboard, IME implementation byte-for-byte.
protected={
 'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
 'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
 'MemoWeaverPinnedSplitView.swift':'0a8c7a49d3510470bd6f42c658fd44290284ad1e6b060e80b3b19fe4f382819a',
 'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
 'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
 'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796',
 'MarkdownPlainEditor.swift':'26115ff0aa756af91518da60706b8765ff5f3123142ad425d6fc5b1726101fd7',
}
for name,original in protected.items():
    assert hashlib.sha256((w/name).read_bytes()).hexdigest()==original, f'Protected file changed: {name}'
install=(r/'install-v0.9.45.sh').read_text()
assert 'test-v0.9.45-visual-context.sh' in install
assert '--verify' in install and '"$ROOT/build.sh"' in install
for script in re.findall(r'^\s+(test-v[0-9.]+[^\s]+\.sh)', install, re.M):
    assert (r/script).is_file(), f'Missing test: {script}'
print('PASS v0.9.45 native titlebar, rail/header baseline, readable context chrome and protected source hashes')
CHECK
if [[ "$(uname -s)" == Darwin ]]; then
    "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library       -framework AppKit -framework SwiftUI       "$ROOT/WorkOSMac/MemoWeaverCommands.swift"       "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift"       "$ROOT/Tests/NativeWindowV0943Smoke.swift" -o "$TMP/native"
    "$TMP/native"
else
    echo 'SKIP: full AppKit/SwiftUI app build and GUI (requires macOS)'
fi
