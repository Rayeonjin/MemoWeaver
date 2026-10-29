#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
cat > "$TMP/main.swift" <<'SWIFT'
import Foundation
func check(_ condition: @autoclosure () -> Bool, _ label: String) {
    if !condition() { fatalError(label) }
}
// One long note; editing near the end must preserve UTF-16 line offsets.
let original = Array(repeating: "한글 + alpha 🌍", count: 12000).joined(separator: "\n")
var text = original
var starts = EditorLineNumberRules.lineStarts(in: text)
check(starts.count == 12000, "initial long note lines")
for edit in 0..<200 {
    let ns = text as NSString
    let at = max(0, ns.length - 45 - edit)
    let replacement = edit.isMultiple(of: 10) ? "\n새 줄" : "x"
    let next = ns.replacingCharacters(in: NSRange(location: at, length: 0), with: replacement)
    let delta = (replacement as NSString).length
    starts = EditorLineNumberRules.updatedLineStarts(previous: starts,
        newText: next, editedRange: NSRange(location: at, length: delta), changeInLength: delta)
    text = next
    check(starts == EditorLineNumberRules.lineStarts(in: text), "edit #\(edit) line indices")
}
check(!MemoryIdlePolicy.mayRun(mode: .automatic, appActive: true,
    secondsSinceEditorActivity: 0.1, secondsSinceAppActivity: 0.1,
    systemIdleSeconds: 500, lowPower: false, thermalPressure: false), "typing blocks AI")
check(MemoryIdlePolicy.mayRun(mode: .automatic, appActive: true,
    secondsSinceEditorActivity: 40, secondsSinceAppActivity: 20,
    systemIdleSeconds: 500, lowPower: false, thermalPressure: false), "long idle permits AI")
check(!MemoryIdlePolicy.mayRun(mode: .manual, appActive: false,
    secondsSinceEditorActivity: 999, secondsSinceAppActivity: 999,
    systemIdleSeconds: 999, lowPower: false, thermalPressure: false), "manual blocks AI")
print("PASS: 12,000-line UTF16 incremental source edits, 200 changes, idle safety")
SWIFT
swiftc -swift-version 5 -Onone "$ROOT/WorkOSMac/EditorLineNumberRules.swift" \
 "$ROOT/WorkOSMac/MemoryIdlePolicy.swift" "$TMP/main.swift" -o "$TMP/editor"
"$TMP/editor"
python3 - "$ROOT" <<'PY2'
from pathlib import Path
import sys,hashlib
r=Path(sys.argv[1]); w=r/'WorkOSMac'
s=(w/'MarkdownPlainEditor.swift').read_text(); a=(w/'MemoryIdleModel.swift').read_text()
caret=s.split('func caretDidMove() {',1)[1].split('    private func applySyntaxColors()',1)[0]
assert 'setNeedsDisplay(visibleRect)' not in caret
assert 'DispatchQueue.main.async(execute: redraw)' in caret
assert 'pendingCaretRedraw?.cancel()' in caret
assert 'setNeedsDisplay(before.insetBy' in caret and 'setNeedsDisplay(next.insetBy' in caret
assert 'private var previousCaretRow: NSRect?' in s
activity=a.split('func editorWasUsed() {',1)[1].split('    func appDidReturnToForeground()',1)[0]
assert 'if (isAutomaticMemoryIndexing || isAutomaticRelationAnalysis)' in activity
assert 'if backgroundAITask == nil { scheduleBackgroundAI() }' in activity
assert 'lastEditorAIPauseAt' in activity
# Avoid any destructive schema update in this performance-focused release.
for row in (r/'QA/review-stability-core-source.sha256').read_text().splitlines():
 digest,name=row.split('  ',1)
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest, name+' changed'
assert 'CREATE TABLE IF NOT EXISTS note_notebooks' in (w/'Storage.swift').read_text()
assert 'CREATE TABLE IF NOT EXISTS virtual_memories' in (w/'Storage.swift').read_text()
print('PASS: caret-row-only invalidations, AI task churn reduced, reviewed core hashes match')
PY2
