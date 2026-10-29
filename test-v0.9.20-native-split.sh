#!/bin/bash
# v0.9.20 Native split source contracts + Foundation-only ideal-size testing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0920-native.XXXXXXXX")"
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
    "$ROOT/Tests/NativeSplitSizingV0920Smoke.swift" -o "$TMP/native-layout"
"$TMP/native-layout"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY_CHECK'
from pathlib import Path
import plistlib, sys
root=Path(sys.argv[1]); w=root/'WorkOSMac'
main=(w/'MainView.swift').read_text()
rules=(w/'NotePreviewRules.swift').read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert plist['CFBundleShortVersionString']=='0.9.35'
assert plist['CFBundleVersion']=='68'
assert plist['CFBundleIdentifier']=='com.local.workos.notes'
assert '@AppStorage("memoweaver.notes.listVisible")' in main
assert '@AppStorage("memoweaver.notes.preferredWidth")' in main
assert '@AppStorage("memoweaver.rightPane.preferredWidth")' in main
assert 'Button(action: toggleNoteList)' in main
assert 'noteListVisible.toggle()' in main
split = (w/'MemoWeaverPinnedSplitView.swift').read_text()
assert 'NSSplitView(frame: .zero)' in split
assert 'NSSplitViewDelegate' in split
assert 'resizeSubviewsWithOldSize' in split
assert 'MemoWeaverPinnedPaneLayout.resolved' in split
assert 'saveListWidth?(width)' in split and 'saveRightWidth?(width)' in split
assert 'NSEvent.pressedMouseButtons' in split
assert 'pendingDragEnd' in split and 'DispatchQueue.main.asyncAfter' in split
assert 'onChanged:' not in split and 'DragGesture' not in split
assert 'NoteWorkspaceLayout.widths(' not in main
assert 'WorkspaceNativeWidthRecorder' not in main
assert 'GeometryReader { split in' not in main
assert '.id(note.id + ":" + model.dataGeneration.uuidString)' in main
assert 'usesCompactList' not in main and 'usesCompactList' not in rules
assert 'CompactNoteListBar' not in main
assert 'popover(isPresented: $showCompactNoteList' not in main
assert '.keyboardShortcut("b", modifiers: [.command, .option])' in main
assert 'setSidePaneVisible(!sidePaneVisible)' in main
print('PASS v0.9.20 source contract: native AppKit splitter, no per-drag SwiftUI state, deferred width persistence, manual list toggle, editor identity and DB unchanged')
PY_CHECK
