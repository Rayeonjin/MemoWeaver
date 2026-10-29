#!/bin/bash
# v0.9.31: validate eight ordered tools, width-dependent overflow, nested menus.
# This is a source-level/Swift parse test. It does not claim macOS GUI QA.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY'
from pathlib import Path
import hashlib,plistlib,re,sys
root=Path(sys.argv[1]); w=root/'WorkOSMac'
chrome=(w/'MemoWeaverEditorChrome.swift').read_text()
core=(w/'MarkdownCore.swift').read_text()
pl=plistlib.loads((w/'Info.plist').read_bytes())
assert (pl['CFBundleShortVersionString'],pl['CFBundleVersion'],pl['CFBundleIdentifier']) == ('0.9.35','68','com.local.workos.notes')
# Read the real source order rather than mirroring it in another implementation.
m=re.search(r'let kinds: \[MarkdownTemplates\.Kind\] = \[([^\]]+)\]',chrome)
assert m, 'Tool order not found'
kinds=re.findall(r'\.(\w+)',m.group(1))
assert kinds==['table','equation','mermaid','markmap','chart','diagram','callout','footnote'],kinds
# Match the candidates actually passed to ViewThatFits, preserving their order.
view=chrome.split('struct MemoWeaverInsertToolbar: View {',1)[1].split('ViewThatFits(in: .horizontal) {',1)[1].split('\n        }',1)[0]
counts=list(map(int,re.findall(r'insertionRow\(visibleCount: (\d+)\)',view)))
assert counts==[8,6,5,4,3,2,1,0],counts
for available_slots in range(1,10):
    direct=8 if available_slots>=8 else max(0,available_slots-1)
    if available_slots==7: direct=6
    visible=kinds[:direct]; hidden=kinds[direct:]
    assert direct in counts
    assert direct + int(bool(hidden)) <= available_slots
    assert len(hidden) != 1
    assert visible+hidden==kinds
    if available_slots==8: assert hidden==[]
    if available_slots==7: assert hidden==['callout','footnote']
    if available_slots==6: assert hidden==['diagram','callout','footnote']
    print(f'PASS slots={available_slots}: visible={visible}, overflow={hidden}')
# No duplicate or flattened diagram commands; the advanced diagram menu survives
# when either visible or nested inside the ellipsis.
assert 'Menu("도식") { diagramChoices }' in chrome
assert 'Menu("차트") { chartChoices }' in chrome
assert 'MermaidDiagramTemplates.Kind.allCases' in chrome
assert 'MermaidChartTemplates.Kind.allCases' in chrome
assert chrome.count('Button("순서도") { onInsert(.mermaid) }')==2
assert 'Menu("Mermaid")' not in chrome
assert 'case .mermaid: return "순서도"' in core
assert 'ForEach(Array(kinds.dropFirst(visibleCount))' in chrome
assert 'if visibleCount < kinds.count {' in chrome
assert 'if kind == .diagram {\n                            Menu("도식") { diagramChoices }' in chrome
assert 'if kind == .chart {\n                            Menu("차트") { chartChoices }' in chrome
# No regression in accepted panel layout or data/attachments layers.
for name,expected in {
    'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
    'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
}.items():
    actual=hashlib.sha256((w/name).read_bytes()).hexdigest()
    assert actual==expected, f'Unexpected change: {name}'
print('PASS v0.9.31 responsive toolbar source and guarded subsystems')
PY
