#!/bin/bash
# Static regression test: both editor variants share a file, only the editable
# variant supports autoFocus. Not a substitute for macOS AppKit type checking.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
python3 - "$ROOT/WorkOSMac/RichEditor.swift" <<'PY2'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
assert s.count('struct RichTextEditor: NSViewRepresentable {') == 1
assert s.count('struct ReadonlyTextView: NSViewRepresentable {') == 1
r, ro = s.split('struct ReadonlyTextView: NSViewRepresentable {',1)
assert 'var autoFocus = false' in r
assert r.count('if autoFocus {') == 1
assert 'autoFocus' not in ro, 'ReadonlyTextView should never request autoFocus'
assert 'scroll.documentView = editor' in ro
assert '.frame(maxWidth: .infinity, minHeight: 160, maxHeight: .infinity)' in (Path(sys.argv[1]).parent/'MarkdownNoteScreen.swift').read_text()
print('PASS: editable editor autofocus retained; readonly view has no undefined autofocus; frame ordering OK')
PY2
