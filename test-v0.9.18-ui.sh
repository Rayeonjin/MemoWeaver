#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0918-ui.XXXXXXXX")"
trap 'rm -rf -- "$TEMP"' EXIT
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
  "$ROOT/WorkOSMac/EditorLineNumberRules.swift" \
  "$ROOT/WorkOSMac/MemoWeaverUIRules.swift" \
  "$ROOT/Tests/UIQualityV0918Smoke.swift" -o "$TEMP/ui-test"
"$TEMP/ui-test"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY_CHECK'
from pathlib import Path
import sys
root=Path(sys.argv[1])
w=root/'WorkOSMac'
main=(w/'MainView.swift').read_text()
note=(w/'MarkdownNoteScreen.swift').read_text()
chrome=(w/'MemoWeaverEditorChrome.swift').read_text()
rules=(w/'NotePreviewRules.swift').read_text()
# A visible insertion button and the overflow menu must be disjoint.
assert 'MemoWeaverInsertToolbar { kind in' in note
assert 'ScrollView(.horizontal, showsIndicators: true)' not in note
assert 'chevron.right.2' not in note
assert 'kinds.prefix(visibleCount)' in chrome and 'kinds.dropFirst(visibleCount)' in chrome
assert 'if visibleCount < kinds.count' in chrome
assert 'ViewThatFits(in: .horizontal)' in chrome
assert 'sourceFormat:' not in chrome and 'sourceFormat:' not in note
# No extra Picker submenu in either the note properties or list filters.
for source in [chrome, main]:
    assert 'Picker("노트북", selection:' not in source
    assert 'Picker("종류", selection:' not in source
assert 'bookID = item.id' in chrome and 'typeID = item.id' in chrome
assert 'model.selectedBookFilterID = book.id' in main
assert 'model.selectedTypeFilterID = item.id' in main
# Keep the left and right panel toggles always accessible.
assert 'private var activityRail: some View' in main
assert 'setSidePaneVisible(!sidePaneVisible)' in main
assert 'Button(action: toggleNoteList)' in main
assert 'NotesNavigationListView()' in main
assert 'MemoWeaverPinnedSplitView(' in main and 'MemoWeaverPinnedPaneLayout' in (w/'MemoWeaverPinnedSplitView.swift').read_text()
assert 'sideTab(.reference' in main and 'sideTab(.preview' in main
assert 'selectedTab = tab' in main
assert 'rightPaneVisibilityOverride' not in main
assert 'Text("로컬 SQLite · 메모와 일정 · 선택형 Ollama AI")' in main
assert '.help("저장 상태: " +' in main
assert 'maximumRightWidth: CGFloat = 1_000' in rules
print('PASS UI v0.9.18 retained controls plus v0.9.20 list toggle, flat menus and stable tab access')
PY_CHECK
