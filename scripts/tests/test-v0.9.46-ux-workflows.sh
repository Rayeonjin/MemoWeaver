#!/bin/bash
# Native window UI contracts + Foundation-only logic. Does not touch user DB.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SWIFTC="$(command -v swiftc)"
if [[ "$(uname -s)" == Darwin ]]; then SWIFTC="$(xcrun --sdk macosx --find swiftc)"; fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0946.XXXXXXXX")"
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
import hashlib, plistlib, sys, re
root=Path(sys.argv[1]); work=root/'WorkOSMac'
read=lambda name: (work/name).read_text()
plist=plistlib.loads((work/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier']) == ('0.9.46','79','com.local.workos.notes')
main=read('MainView.swift')
rail=main.split('private var activityRail: some View {')[1].split('private var railStorageNeedsAttention:')[0]
for removed in ['railButton(.archives','railButton(.trash','railButton(.assistant']:
    assert removed not in rail, removed
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in main
assert 'model.selectedPage == .trash ? "trash.fill" : "trash"' in main
assert '.popover(isPresented: $showQuickSearch' in main and '.sheet(isPresented: $showQuickSearch' not in main
assert 'MemoWeaverSideAssistantPane(noteID: currentNoteID)' in main
assert 'MemoWeaverSettingsSection: String, CaseIterable' in main
assert 'if selectedSection == "about"' in main
assert '기존 TXT 자료 보기' in main and 'TXT 파일 가져오기…' in main
search=read('MemoWeaverQuickSearchPalette.swift')
assert 'Button { dismiss() }' in search and '.onExitCommand { dismiss() }' in search
assert 'case archives = "기존 TXT 자료"' in search
native=read('MemoWeaverNativeWindowChrome.swift')
assert 'window.titlebarAppearsTransparent = true' in native
assert 'let height: CGFloat = isText ? 20 : 28' in native
assert 'NSTrackingSeparatorToolbarItem(' not in native
assert 'insertItem(' not in native and 'removeItem(' not in native
assert 'tabs.segmentCount = 4' in native
assert 'case "assistant": selected = 3' in native
assert 'case 3: tab = "assistant"' in native
pane=read('NotePreviewRules.swift')
assert 'case assistant' in pane and 'case preview' in pane
assistant=read('MemoWeaverSideAssistantPane.swift')
assert 'model.askAI()' in assistant and 'model.openSource(source)' in assistant
assert '현재 메모만으로 범위를 제한' in assistant
graph=read('MemoryMapViews.swift')
assert 'MemoryGraphFocusCore.subset' in graph
assert 'Text("선택 메모 중심")' in graph and 'Text("전체 연결")' in graph
protected={
  'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
  'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
  'MemoWeaverPinnedSplitView.swift':'0a8c7a49d3510470bd6f42c658fd44290284ad1e6b060e80b3b19fe4f382819a',
  'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
  'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
  'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796',
  'MarkdownPlainEditor.swift':'26115ff0aa756af91518da60706b8765ff5f3123142ad425d6fc5b1726101fd7',
}
for filename,expected in protected.items():
    assert hashlib.sha256((work/filename).read_bytes()).hexdigest()==expected, 'Core modified: '+filename
install=(root/'install-v0.9.46.sh').read_text()
assert 'test-v0.9.46-ux-workflows.sh' in install
assert '"$ROOT/build.sh"' in install
for name in re.findall(r'^\s+(test-v[0-9.]+[^\s]+\.sh)',install,re.M):
    assert (root/name).is_file(), 'Missing test: '+name
print('PASS v0.9.46 static UI contracts, persistence, 7 core SHA256, installer paths')
CHECK
if [[ "$(uname -s)" == Darwin ]]; then
  "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    -framework AppKit -framework SwiftUI \
    "$ROOT/WorkOSMac/MemoWeaverCommands.swift" \
    "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
    "$ROOT/Tests/NativeWindowV0943Smoke.swift" -o "$TMP/native"
  "$TMP/native"
else
  echo 'SKIP native AppKit/SwiftUI compile & actual UI (requires macOS)'
fi
