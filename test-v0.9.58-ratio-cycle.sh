#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/main.swift" <<'SWIFT'
import Foundation
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    if !condition() { fatalError(label) }
}
check(MemoWeaverPaneRatioPreset.allCases.count == 3, "all presets retained")
check(MemoWeaverPaneRatioPreset.next(afterEditorPercent: nil) == .editor60, "first click")
check(MemoWeaverPaneRatioPreset.next(afterEditorPercent: 50) == .editor60, "50 -> 60")
check(MemoWeaverPaneRatioPreset.next(afterEditorPercent: 60) == .editor70, "60 -> 70")
check(MemoWeaverPaneRatioPreset.next(afterEditorPercent: 70) == .equal, "70 -> 50")
check(MemoWeaverPaneRatioPreset.next(afterEditorPercent: 35) == .editor60, "custom 35 -> 60")
check(MemoWeaverPaneRatioPreset.next(afterEditorPercent: 85) == .equal, "custom 85 -> 50")
check(MemoWeaverPinnedPaneLayout.editorPercent(editorWidth: 500, rightWidth: 500) == 50, "equal")
check(MemoWeaverPinnedPaneLayout.editorPercent(editorWidth: 600, rightWidth: 400) == 60, "60:40")
check(MemoWeaverPinnedPaneLayout.editorPercent(editorWidth: 700, rightWidth: 300) == 70, "70:30")
check(MemoWeaverPinnedPaneLayout.editorPercent(editorWidth: 0, rightWidth: 100) == nil, "hidden")
check(MemoWeaverPinnedPaneLayout.editorPercent(editorWidth: .infinity, rightWidth: 100) == nil, "invalid")
check(MemoWeaverPinnedPaneLayout.rightWidth(for: .editor70, combinedWidth: 400) == nil, "minimum guard")
check(MemoWeaverPinnedPaneLayout.rightWidth(for: .equal, combinedWidth: 1000) == 500, "actual split")
print("PASS: measured ratio, cycle order, minimum widths, invalid geometry")
SWIFT
swiftc -swift-version 5 -Onone "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" "$TMP/main.swift" -o "$TMP/ratios"
"$TMP/ratios"
python3 - "$ROOT" <<'PY2'
import sys
from pathlib import Path
r=Path(sys.argv[1])/'WorkOSMac'
m=(r/'MainView.swift').read_text(); s=(r/'MemoWeaverPinnedSplitView.swift').read_text()
assert 'private var ratioCycleButton: some View' in m
assert 'private var ratioMenu: some View' not in m
assert 'Menu {' not in m.split('private var ratioCycleButton:',1)[1].split('private struct NoteListRow:',1)[0]
assert 'Text("\(percent):\(100 - percent)")' in m
assert 'onRatioMeasured:' in m and 'editorRatioPercent: currentEditorRatioPercent' in m
assert 'reportMeasuredRatio(in: splitView)' in s
assert 'private func reportMeasuredRatio(in split:' in s
assert 'DispatchQueue.main.async { callback?(percent) }' in s
assert 'self.reportMeasuredRatio(in: split)' in s
assert 'lastMeasuredRatioPercent' in s
assert 'Image(systemName: "textformat.size")' not in (r/'MemoWeaverEditorChrome.swift').read_text()
print('PASS: no ratio dropdown, one-click cycling, live native measurement, font glyph removed')
PY2
