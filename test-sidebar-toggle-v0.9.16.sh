#!/bin/bash
# UI regression: both navigation toggles are in the document view, not in
# overflowable macOS toolbar items. Visual GUI verification is still required.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
python3 - "$ROOT/WorkOSMac/MainView.swift" <<'PY_CHECK'
from pathlib import Path
import sys
code=Path(sys.argv[1]).read_text()
assert 'private var activityRail: some View' in code
assert '.frame(width: 52)' in code
assert 'railButton(.all, title: "메모"' in code
assert '.help(title)' in code and '.onHover { hovered in' in code
assert 'private var fixedWorkspaceControls: some View {' in code
assert 'setSidePaneVisible(!sidePaneVisible)' in code
assert '.keyboardShortcut("r", modifiers: [.command, .option])' in code
assert '.accessibilityLabel' in code
assert 'ToolbarItem' not in code
assert 'NavigationSplitView(' not in code
assert 'toggleNavigationPane' not in code
assert 'if !focusModeEnabled {' in code and 'focusModeEnabled.toggle()' in code
assert 'memoweaver.navigationPane.visible' not in code
print('PASS single fixed activity rail, right panel toggle and reversible focus, without old sidebar overflow')
PY_CHECK
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
bash -n "$ROOT/install-v0.9.20.sh" "$ROOT/build.sh" "$ROOT/install.sh"
