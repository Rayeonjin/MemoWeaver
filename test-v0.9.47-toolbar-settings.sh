#!/bin/bash
# v0.9.47: titlebar divider source contract and single-page anchor settings.
# Doesn't alter installed app, real SQLite, or user configuration.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then SWIFTC="$(xcrun --sdk macosx --find swiftc)"; fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0947.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MemoryGraphFocusCore.swift" \
  "$ROOT/Tests/MemoryGraphFocusV0946Smoke.swift" -o "$TMP/graph"
"$TMP/graph"
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/Tests/MarkdownAssistCatalogV0945Smoke.swift" -o "$TMP/context"
"$TMP/context"
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
  "$ROOT/Tests/PinnedPaneVisibilityV0929Smoke.swift" -o "$TMP/panes"
"$TMP/panes"
python3 - "$ROOT" <<'CHECK'
from pathlib import Path
import hashlib, plistlib, re, sys
root=Path(sys.argv[1]); work=root/'WorkOSMac'
read=lambda name:(work/name).read_text()
plist=plistlib.loads((work/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier']) == ('0.9.47','80','com.local.workos.notes')
main=read('MainView.swift')
rail=main.split('private var activityRail: some View {')[1].split('private func railIsSelected')[0]
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in rail
assert 'Divider()' not in rail and '.overlay(alignment: .bottom)' not in rail
assert 'settingsSection = "about"' not in rail
assert 'MemoWeaverStorageStatus.symbol' not in rail
assert 'railButton(.settings' in rail
settings=main.split('private struct SettingsScreen: View {',1)[1]
assert 'ScrollViewReader { proxy in' in settings
assert 'LazyVStack(alignment: .leading, spacing: 28)' in settings
assert 'ForEach(MemoWeaverSettingsSection.allCases)' in settings
assert '.id(section.rawValue)' in settings
assert 'proxy.scrollTo(section.rawValue, anchor: .top)' in settings
assert '.onAppear {' in settings and 'proxy.scrollTo(saved.rawValue, anchor: .top)' in settings
assert 'if selectedSection ==' not in settings, 'old conditional page switching remains'
sections=['appearance','editor','ai','reminders','data','categories','about']
for section in sections:
    assert f'case .{section}:' in settings
for preserved in ['전체 JSON 백업','JSON 백업 시점으로 전체 복원','기존 TXT 자료','AI 기억 비서 전체 화면','Markdown 문법 색상 표시','노트북 이름','Mac 알림 권한 요청','WorkOSBuildInfo.display']:
    assert preserved in settings, preserved
native=read('MemoWeaverNativeWindowChrome.swift')
assert 'canvas.separatorXs = edges' in native and 'canvas.separatorXs = []' in native
assert 'if valid, let split {' in native
assert 'viewX(children[1].frame.minX) - thickness' in native
assert 'viewX(children[expected - 1].frame.minX) - thickness' in native
assert 'NSColor.separatorColor.setFill()' in native
assert 'updateTitlebarRailRule(in: canvas, window: window)' in native
assert 'rule.isHidden = snapshot.focusMode' in native
assert 'override func hitTest(_ point: NSPoint) -> NSView? { nil }' in native
assert 'NSTrackingSeparatorToolbarItem(' not in native
assert 'insertItem(' not in native and 'removeItem(' not in native
assert 'static func order(_ state: MemoWeaverToolbarSnapshot)' in native
assert '[workspace]' in native
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
    actual=hashlib.sha256((work/name).read_bytes()).hexdigest()
    assert actual == expected, f'protected core changed: {name}'
install=(root/'install-v0.9.47.sh').read_text()
assert 'test-v0.9.47-toolbar-settings.sh' in install and '"$ROOT/build.sh"' in install
for name in re.findall(r'^\s+(test-v[0-9.]+[^\s]+\.sh)',install,re.M):
    assert (root/name).is_file(), f'missing installer test {name}'
print('PASS v0.9.47: 7 anchor sections, rail cleanup, native toolbar boundaries, no tracking items, protected 7 SHA256, installer')
CHECK
if [[ "$(uname -s)" == Darwin ]]; then
    "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
      -framework AppKit -framework SwiftUI \
      "$ROOT/WorkOSMac/MemoWeaverCommands.swift" \
      "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
      "$ROOT/Tests/NativeWindowV0943Smoke.swift" -o "$TMP/native"
    "$TMP/native"
else
    echo 'SKIP native AppKit/SwiftUI typecheck and GUI (requires macOS)'
fi
