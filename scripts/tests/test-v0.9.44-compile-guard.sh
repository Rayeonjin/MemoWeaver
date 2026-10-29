#!/bin/bash
# MemoWeaver v0.9.44 Build 77: guarded compile + regression tests.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0944.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
# Typecheck the exhaustive MarkdownEditingContext switch without SwiftUI.
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
    "$ROOT/Tests/MarkdownSlashPaletteV0944Smoke.swift" -o "$TMP/slash-caption"
"$TMP/slash-caption"
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
    "$ROOT/Tests/MarkdownContextV0943Smoke.swift" -o "$TMP/context"
"$TMP/context"
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
    "$ROOT/Tests/PinnedPaneVisibilityV0929Smoke.swift" -o "$TMP/panes"
"$TMP/panes"
python3 - "$ROOT" <<'CHECK'
from pathlib import Path
import hashlib, plistlib, re, sys
r=Path(sys.argv[1]); w=r/'WorkOSMac'
read=lambda n:(w/n).read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier']) == ('0.9.44','77','com.local.workos.notes')
core=read('MarkdownSyntaxCore.swift')
slash=read('MarkdownSlashPalette.swift')
assert 'case .markmap: return "Markmap 마인드맵"' in core
assert 'switch self {' in core[core.index('var slashPaletteTitle: String') : core.index('// Determine the Mermaid dialect')]
assert 'context.slashPaletteTitle' in slash
assert 'switch context' not in slash, 'Do not reintroduce a UI-only switch untested on Linux'
chrome=read('MemoWeaverNativeWindowChrome.swift')
assert 'NSTrackingSeparatorToolbarItem(' not in chrome
assert 'toolbar.insertItem' not in chrome and 'toolbar.removeItem' not in chrome
assert 'window.toolbar = toolbar' in chrome
install=(r/'install-v0.9.44.sh').read_text()
assert 'test-v0.9.44-compile-guard.sh' in install
assert 'test-v0.9.43-native-zoned-toolbar.sh' not in install
assert 'test-v0.9.27-pinned-paste-ui.sh' in install
for script in re.findall(r'^\s+(test-v[0-9.]+[^\s]+\.sh)', install, re.M):
    assert (r/script).is_file(), f'Installer references missing test: {script}'
# No storage, pane, clipboard, IME or existing editor changes in this hotfix.
preserved={
 'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
 'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
 'MemoWeaverPinnedSplitView.swift':'0a8c7a49d3510470bd6f42c658fd44290284ad1e6b060e80b3b19fe4f382819a',
 'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
 'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
 'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796',
 'MarkdownPlainEditor.swift':'26115ff0aa756af91518da60706b8765ff5f3123142ad425d6fc5b1726101fd7',
 'MarkdownNoteScreen.swift':'7165dda7826b47b1ba8943424e9bcbc9a0139d80011e47b90e824051efe6a46e',
 'MemoWeaverNativeWindowChrome.swift':'8936c74f5bb1013d5b385c1bff04a76ec8c4915d4dcd7e2b24e41f5204349ddd',
}
for file,digest in preserved.items():
    got=hashlib.sha256((w/file).read_bytes()).hexdigest()
    assert got == digest, f'Protected source changed: {file}'
print('PASS v0.9.44: installer, toolbar crash guard, bundle ID, protected source hashes')
CHECK
if [[ "$(uname -s)" == Darwin ]]; then
    "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
       -framework AppKit -framework SwiftUI \
       "$ROOT/WorkOSMac/MemoWeaverCommands.swift" \
       "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
       "$ROOT/Tests/NativeWindowV0943Smoke.swift" -o "$TMP/native"
    "$TMP/native"
else
    echo 'SKIP: AppKit smoke and full app compile (macOS only)'
fi
