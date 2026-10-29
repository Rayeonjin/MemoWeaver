#!/bin/bash
# Foundation-only ratio math + native UI wiring smoke test (macOS/Linux).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/main.swift" <<'SWIFT'
import Foundation

func approx(_ actual: CGFloat?, _ expected: CGFloat, _ label: String) {
    guard let actual = actual, abs(actual - expected) <= 0.1 else {
        fatalError("\(label): expected \(expected), got \(String(describing: actual))")
    }
}
let model = MemoWeaverPinnedPaneLayout.self
assert(MemoWeaverPaneRatioPreset.allCases.count == 3)
assert(model.rightWidth(for: .editor70, combinedWidth: 400) == nil)
assert(model.rightWidth(for: .equal, combinedWidth: .nan) == nil)
assert(model.rightWidth(for: .equal, combinedWidth: .infinity) == nil)
approx(model.rightWidth(for: .editor70, combinedWidth: 1000), 300, "70:30")
approx(model.rightWidth(for: .editor60, combinedWidth: 1000), 400, "60:40")
approx(model.rightWidth(for: .equal, combinedWidth: 1000), 500, "50:50")
// On a narrow window the minimum editor/auxiliary widths win over percentages.
approx(model.rightWidth(for: .editor70, combinedWidth: 430), 190, "right minimum")
approx(model.rightWidth(for: .equal, combinedWidth: 430), 190, "editor minimum")
// No matter whether the memo list is visible, the combined workspace
// excludes its width and native dividers.
for listVisible in [false, true] {
    let listWidth: CGFloat = listVisible ? 245 : 0
    let total: CGFloat = 1000 + listWidth + (listVisible ? 2 : 1)
    for preset in MemoWeaverPaneRatioPreset.allCases {
        let target = model.rightWidth(for: preset, combinedWidth: 1000)!
        let widths = model.resolved(totalWidth: total, dividerThickness: 1,
            listVisible: listVisible, rightVisible: true,
            savedListWidth: listWidth, savedRightWidth: target)
        assert(abs(widths.editor + widths.right - 1000) <= 0.01)
        assert(abs(widths.right - target) <= 0.01)
        assert(widths.editor >= model.editorMinimum)
        assert(widths.right >= model.rightMinimum)
    }
}
print("PASS: ratio presets, narrow window guard, both list states, persisted width model")
SWIFT
swiftc -Onone "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" "$TMP/main.swift" -o "$TMP/check"
"$TMP/check"
python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path
root=Path(sys.argv[1])/'WorkOSMac'
main=(root/'MainView.swift').read_text()
split=(root/'MemoWeaverPinnedSplitView.swift').read_text()
assert 'private var ratioMenu: some View' in main
assert 'onApplyRatio: applyRightPaneRatio' in main
assert 'rightPaneRatioRequest = MemoWeaverPaneRatioRequest' in main
assert 'ratioRequest: rightPaneRatioRequest' in main
assert 'MemoWeaverThemePicker(selection: $previewAppearance' in main
assert 'state.applyRatioPreset(request.preset, in: split)' in split
assert 'state.lastRatioRequestID = request.id' in split
assert 'lastRatioRequestID = nil' in split
assert 'split.insertArrangedSubview(pane, at: index)' in split
print('PASS: native split/menu one-shot callback, existing divider retained')
PY
