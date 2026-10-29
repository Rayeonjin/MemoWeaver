#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SWIFTC="$(command -v swiftc)"
"$SWIFTC" -frontend -parse "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT/WorkOSMac/ReferenceWorkspacePane.swift" <<'PY_CHECK'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
parent = s.split('struct ReferenceWorkspacePane: View {',1)[1].split('private struct ReferenceRowActions',1)[0]
assert 'ForEach(' not in parent, 'large parent ViewBuilder has a ForEach again'
assert 'private struct ReferenceLinkedRows: View' in s
assert 'private struct ReferenceSearchRows: View' in s
assert r'ForEach(entries, id: \.id)' in s
assert r'ForEach(results, id: \.id)' in s
assert 'private struct ReferenceMemoRow: View' in s
assert 'private struct ReferenceMemoBody: View' in s
assert 'private struct ManualMemoryLinkEditor: View' in s
assert 'private var rowHeader: some View' in s
assert 'private var actionButtons: some View' in s
assert 'private var renderedOrRaw: some View' in s
assert 'selectedNoteID =' not in s
print('PASS BUILD FIX 2: Swift source parsed; independent linked/search lists; small cards; editor selection unchanged')
PY_CHECK
