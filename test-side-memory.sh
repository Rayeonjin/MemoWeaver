#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d /tmp/memoweaver-side-memory.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  PLATFORM=(-sdk "$SDK" -target "$(uname -m)-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
  PLATFORM=()
fi
"$SWIFTC" -swift-version 5 -Onone "${PLATFORM[@]}"   "$ROOT/WorkOSMac/SideMemoryRules.swift" "$ROOT/Tests/SideMemorySmoke.swift" -o "$TEMP/side-memory-smoke"
"$TEMP/side-memory-smoke"
python3 - "$ROOT" <<'PY_CHECK'
from pathlib import Path
import sys
r=Path(sys.argv[1])/'WorkOSMac'
m=(r/'MainView.swift').read_text();v=(r/'SideMemoryPane.swift').read_text();
ed=(r/'MarkdownPlainEditor.swift').read_text(); n=(r/'MarkdownNoteScreen.swift').read_text()
assert 'Text("연결").tag(NoteSidePaneTab.memory)' in m
assert 'SideMemoryPane(noteID: currentNoteID, caretLine: previewCaretLine)' in m
assert 'func sideMemoryNeighbors(centerID: String' in (r/'MemoryModel.swift').read_text()
assert 'model.openMemoryNeighbor(neighbor)' in v and 'maxCount: 40' in (r/'MemoryModel.swift').read_text()
assert 'manager.invalidateDisplay(forCharacterRange:' in ed
assert 'setNeedsDisplay(visibleRect)' in ed
assert 'syntaxColorsEnabled: syntaxColorsEnabled' in n
assert 'memoweaver.editor.syntaxColorsEnabled' in m
print('PASS v0.9.10 source anchors: tab, graph, open source, repaint, syntax fallback')
PY_CHECK
