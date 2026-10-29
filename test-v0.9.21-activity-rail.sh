#!/bin/bash
# Activity rail is the only navigation; retain its split/edit/save guarantees.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0921-rail.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
ARGS=(-swift-version 5 -Onone -j 1 -parse-as-library)
if [[ "$(uname -s)" == Darwin ]]; then
    export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
    SWIFTC="$(xcrun --sdk macosx --find swiftc)"
    ARGS+=(-sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macosx14.0")
fi
"$SWIFTC" "${ARGS[@]}" \
    "$ROOT/WorkOSMac/Models.swift" \
    "$ROOT/WorkOSMac/QuickCaptureCore.swift" \
    "$ROOT/WorkOSMac/WorkBlocks.swift" \
    "$ROOT/WorkOSMac/NotePreviewRules.swift" \
    "$ROOT/Tests/ActivityRailV0921Smoke.swift" -o "$TMP/rail"
"$TMP/rail"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY_CHECK'
import plistlib,sys
from pathlib import Path
r=Path(sys.argv[1]);w=r/'WorkOSMac'
main=(w/'MainView.swift').read_text()
editor=(w/'MarkdownNoteScreen.swift').read_text()
app=(w/'WorkOSApp.swift').read_text()
rules=(w/'NotePreviewRules.swift').read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier']) == ('0.9.35','68','com.local.workos.notes')
assert 'compactShell' in main and 'legacyShell' not in main
rail=main.split('    private var activityRail: some View {',1)[1].split('    private var railStorageNeedsAttention:',1)[0]
for route in ['.all','.search','.today','.planner','.archives','.memory','.assistant','.trash','.settings']:
    assert 'railButton('+route+',' in rail, route
assert '.frame(width: 52)' in rail and 'Spacer(minLength: 6)' in rail
assert 'railButton(.settings' in rail and 'railButton(.trash' in rail
assert '.accessibilityLabel(title)' in main and '.accessibilityValue(selected ?' in main
assert 'model.selectedPage = page' in main and 'if page == .all || page == .trash { noteListVisible = true }' in main
assert 'NavigationSplitView(' not in main and 'memoWeaverToggleFocusMode' in main
assert 'NotesNavigationListView()' in main and 'MemoWeaverPinnedSplitView(' in main
assert 'MemoWeaverPinnedSplitView(' in main
assert 'NoteSidePaneRules.isVisibleForLayout' in main and 'if compactNavigation && override == nil { return false }' in rules
assert 'noteListVisible.toggle()' in main and 'setSidePaneVisible(!sidePaneVisible)' in main
assert 'sideTab(.memory, title: "연결"' in main.split('private struct WorkOSUnifiedRightPane:',1)[1]
assert 'MemoWeaverLayoutSwitchSafety.prepare()' in main and '집중 모드 전환' in app
assert 'memoWeaverBeforeLayoutChange' in editor and 'flush(checkpoint: false)' in editor
assert 'canProceed = !isDirty' in editor and 'editor.hasMarkedText()' in main
assert 'compactNavigationEnabled' not in main and '간결한 탐색 화면으로 바꾸기' not in app
assert '.keyboardShortcut("0", modifiers: [.command, .option])' not in app
assert 'GroupBox("탐색 화면 구성")' not in main
assert 'TextField("메모 목록에서 찾기"' in main.split('private var filteringControls: some View {',1)[1].split('private var bookFilter:',1)[0]
assert '.id(note.id + ":" + model.dataGeneration.uuidString)' in main
assert 'WorkOSDraftRecovery' not in main
print('PASS v0.9.21 source contracts: nine routes, single rail, native splitter, reversible focus, safe editor flush, no auto-collapse')
PY_CHECK
