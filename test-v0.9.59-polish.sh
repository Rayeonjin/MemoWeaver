#!/bin/bash
# The v0.9.59 release intentionally DOES NOT add formatting toolbar actions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mw59-smoke.XXXXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
swiftc -swift-version 5 -typecheck "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
    "$ROOT/WorkOSMac/MemoWeaverThemeCycleCore.swift"
swiftc -swift-version 5 -Onone "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
    "$ROOT/WorkOSMac/MemoWeaverThemeCycleCore.swift" \
    "$ROOT/Tests/MathAndThemeV0959Smoke.swift" -o "$TEMP/math-theme"
"$TEMP/math-theme"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys,plistlib,hashlib
r=Path(sys.argv[1]); p=r/'WorkOSMac'
read=lambda name:(p/name).read_text()
main=read('MainView.swift'); tool=read('MemoWeaverEditorChrome.swift'); footer=read('MemoWeaverPaneFooter.swift'); math=read('MarkdownNoteScreen.swift'); syntax=read('MarkdownSyntaxCore.swift')
plist=plistlib.loads((p/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'])==('0.9.59','92')
# User preference: keep Markdown syntax native, no formatting B/I/H/list toolbar.
section=tool.split('struct MemoWeaverInsertToolbar: View {',1)[1].split('// Scratch/Notion-style quick table insertion.',1)[0]
assert '.table, .equation, .mermaid, .markmap, .chart, .diagram, .callout, .footnote' in section
for rejected in ['formatButton(', 'formattingControls(', 'formatOverflowMenu', 'headingMenu', 'onFormat', 'case .bold', '.italic', 'MarkdownFormatCommand']:
    assert rejected not in section, f'formatting toolbar introduced: {rejected}'
assert not (p/'MarkdownFormattingCore.swift').exists()
assert 'formatRequest' not in read('MarkdownPlainEditor.swift')
assert 'formatRequest' not in math
assert 'ViewThatFits(in: .horizontal)' in section
assert 'if kind == .mermaid || kind == .callout' in section
assert section.count('MemoWeaverHeaderIconSurface(height: 26)') >= 5
# Native footer: title left, controls right, cycle button in both panes.
assert 'footerRow(showFollowCaret: false, truncateTitle: true)' in main
assert 'Spacer(minLength: truncateTitle ? 4 : 8)' in main
assert 'presentation: .cycleButton' in main
assert 'presentation: .cycleButton' in tool
assert 'case .cycleButton:' in footer
assert 'selection = MemoWeaverThemeCycleCore.next(after: selection)' in footer
assert 'let percent = editorRatioPercent ?? 50' in main
# Multiline math accessible from math palette, no source rewriters.
assert 'case .math: return [.fraction, .squareRoot, .gatheredEquations, .alignedEquations]' in math
assert 'case .gatheredEquations:' in syntax and 'case .alignedEquations:' in syntax
assert 'String.raw' not in section
# Protect all storage and hotpath files from accidental changes.
for row in (r/'QA/v0.9.58-core-source.sha256').read_text().splitlines():
    digest, relative = row.split('  ',1)
    actual=hashlib.sha256((r/relative).read_bytes()).hexdigest()
    assert digest==actual, f'unexpected critical file change: {relative}'
print('PASS: no formatting buttons, stable insert group design, footer alignment, two theme cycles, protected data')
PY
