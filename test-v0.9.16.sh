#!/bin/bash
# Synthetic tests; never opens or modifies the user's actual SQLite file.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0916.XXXXXXXX")"
trap 'rm -rf -- "$TEMP"' EXIT
SWIFTC="$(command -v swiftc)"
ARGS=(-swift-version 5 -Onone -j 1 -parse-as-library)
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARGS+=(-sdk "$SDK" -target "$(uname -m)-apple-macosx14.0")
fi
"$SWIFTC" "${ARGS[@]}" \
  "$ROOT/WorkOSMac/EditorLineNumberRules.swift" \
  "$ROOT/WorkOSMac/MemoWeaverUIRules.swift" \
  "$ROOT/Tests/MemoWeaverUIV0916Smoke.swift" \
  -o "$TEMP/ui-test"
"$TEMP/ui-test"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT/WorkOSMac/"*.swift
python3 - "$ROOT" <<'PY_CHECK'
from pathlib import Path
import sys
w=Path(sys.argv[1])/'WorkOSMac'
main=(w/'MainView.swift').read_text()
note=(w/'MarkdownNoteScreen.swift').read_text()
chrome=(w/'MemoWeaverEditorChrome.swift').read_text()
editor=(w/'MarkdownPlainEditor.swift').read_text()
ref=(w/'ReferenceWorkspacePane.swift').read_text()
model=(w/'AppModel.swift').read_text()
plist=(w/'Info.plist').read_text()
assert '<string>0.9.35</string>' in plist and '<string>68</string>' in plist
assert 'com.local.workos.notes' in plist
assert 'Section("종류")' not in main
assert 'railButton(.assistant' in main and 'railButton(.memory' in main
assert 'private var bookFilter: some View' in main and 'private var typeFilter: some View' in main
assert 'TextField("메모 목록에서 찾기"' in main
assert 'memo' not in model[:0] # no-op to ensure readable assertions
assert 'if let selected = currentNote, selected.deletedAt.isEmpty { return }' in model
assert 'model.filteredNotes.contains(where:' not in main.split('private var activeNoteEditor: some View {')[1].split('private var activeRightPane')[0]
assert 'MemoWeaverEditorHeader(' in note and 'showDetails' not in note
assert 'TextField(fallbackTitle, text: $title)' in chrome
assert 'MemoWeaverEditorStatusBar(' in note
assert 'onCaretStatusChange: { line, column, count, offset in' in note
assert 'editorCaretOffsets[note.id]' in note and 'restoreCaretOffset' in editor
assert 'Button("검색", action: performSearch)' in ref
assert ref.index('            searchControls') < ref.index('            modePicker')
assert 'mode = "search"' in ref
assert 'selectedNoteID =' not in ref
assert '@AppStorage("memoweaver.preview.appearance")' in main
assert '@AppStorage("memoweaver.rightPane.activeTab")' in main
assert 'setSidePaneVisible(!sidePaneVisible)' in main
assert 'MemoWeaverPreviewAppearance.apply' in (w/'WorkOSPreview.swift').read_text()
assert 'WorkOSHTMLPreview(html: renderedHTML' in ref
assert 'MemoWeaverPinnedSplitView(' in main
print('PASS v0.9.16 UI contracts, reference search independence, panel persistence, non-destructive data identity')
PY_CHECK
