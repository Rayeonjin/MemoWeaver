#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 - <<'PYTEST'
from pathlib import Path
root=Path('WorkOSMac')
a=(root/'MainView.swift').read_text()
assert 'Text("MD")' not in a
assert 'Label(bookName, systemImage: "folder")' in a
assert 'Label(typeName, systemImage: "tag")' in a
assert 'memoweaver.ui.tooltipsEnabled' in a
assert 'Text(saveLabel)' not in (root/'MemoWeaverEditorChrome.swift').read_text()
assert 'compactMathLabel' in (root/'MarkdownSyntaxCore.swift').read_text()
assert (root/'MemoWeaverTooltips.swift').exists()
print('PASS v0.9.50 tooltip/list/status/math source checks')
PYTEST
swiftc -frontend -parse WorkOSMac/*.swift
