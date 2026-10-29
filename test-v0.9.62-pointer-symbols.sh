#!/bin/bash
# v0.9.62: slash command pointer path, large math symbol picker, core safety.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-pointer-symbols-62.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
swiftc -swift-version 5 -Onone -parse-as-library \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/WorkOSMac/MemoWeaverMathSymbolCatalog.swift" \
  "$ROOT/Tests/MathSymbolV0962Smoke.swift" -o "$TMP/symbols"
"$TMP/symbols"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import hashlib, plistlib, sys
r=Path(sys.argv[1]); w=r/'WorkOSMac'
slash=(w/'MarkdownPlainEditor.swift').read_text()
palette=(w/'MarkdownSlashPalette.swift').read_text()
math=(w/'MemoWeaverMathSymbolPicker.swift').read_text()
header=(w/'MarkdownNoteScreen.swift').read_text()
assert 'popup.behavior = .applicationDefined' in slash, 'popover must permit full click sequence'
assert 'popup.behavior = .transient' not in slash
assert 'watchSlashMouseClicks(in: editor)' in slash
assert 'event.window' in slash and 'targetWindow === paletteWindow' in slash
assert 'return event' in slash, 'outside-click monitor must not consume original mouse event'
assert 'NSEvent.removeMonitor(slashMouseDownMonitor)' in slash, 'monitor lifetime must be controlled'
assert 'DispatchQueue.main.async { [weak self, weak editor] in' in slash
assert 'self.insertSlash(item, in: editor)' in slash
assert 'source.substring(with: trigger.range) == "/" + trigger.query' in slash, 'stale text guard'
assert 'editor.insertText(prepared.source, replacementRange: trigger.range)' in slash
assert 'editor.window?.makeFirstResponder(editor)' in slash
assert 'onHover { inside in' in palette and '.contentShape(RoundedRectangle' in palette
assert 'Button { onSelect(item) }' in palette
assert 'Enter 또는 클릭' in palette
assert 'MemoWeaverMathSymbolCatalog.sections' in math
assert 'size: 25' in math and 'frame(height: 61)' in math
assert '.onHover { isInside in' in math and 'Button { onInsert(snippet) }' in math
assert 'MemoWeaverMathSymbolPicker { snippet in' in header
assert 'Button("기호 크게 보기…")' in header
assert 'groupSymbolsVisible' in header and 'overflowSymbolsVisible' in header
assert '.frame(height: 30, alignment: .center)' in header, 'toolbar row stays 30 pt'
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'], plist['CFBundleVersion']) == ('0.9.62','95')
assert plist['CFBundleIdentifier']=='com.local.workos.notes'
for row in (r/'QA/v0.9.60-core-source.sha256').read_text().splitlines():
    digest,name=row.split('  ',1)
    assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest, name+' changed'
print('PASS v0.9.62: pointer-selectable slash popover contract, guard, dismissal and editor focus')
print('PASS v0.9.62: enlarged symbol grid and 30pt toolbar contract; protected sources unchanged')
PY
