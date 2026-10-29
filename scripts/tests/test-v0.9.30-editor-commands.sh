#!/bin/bash
# v0.9.30 UI commands, context menu, metadata and font boundaries.
# No user data, application installation or UI automation is performed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0930.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -swift-version 5 -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/EditorTypographyRules.swift" \
  "$ROOT/Tests/EditorUXV0930Smoke.swift" -o "$TMP/typography"
"$TMP/typography"
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY'
from pathlib import Path
import plistlib,sys,hashlib
r=Path(sys.argv[1]); w=r/'WorkOSMac'
m=(w/'MainView.swift').read_text()
c=(w/'MemoWeaverEditorChrome.swift').read_text()
n=(w/'MarkdownNoteScreen.swift').read_text()
pl=plistlib.loads((w/'Info.plist').read_bytes())
assert (pl['CFBundleShortVersionString'],pl['CFBundleVersion'],pl['CFBundleIdentifier']) == ('0.9.35','68','com.local.workos.notes')
# Eight tools, dynamic overflow with no singleton orphan.
assert 'let kinds: [MarkdownTemplates.Kind]' in c
assert '.table, .equation, .mermaid, .markmap, .chart, .diagram, .callout, .footnote' in c
assert 'insertionRow(visibleCount: 8)' in c
assert 'insertionRow(visibleCount: 5)' in c
assert 'insertionRow(visibleCount: 6)' in c and 'insertionRow(visibleCount: 7)' not in c
assert 'Button("순서도") { onInsert(.mermaid) }' in c
assert 'Menu("도식") { diagramChoices }' in c
assert 'diagramChoices' in c and 'MermaidDiagramTemplates.Kind.allCases' in c
assert 'Menu("차트") { chartChoices }' in c
assert 'Menu("Mermaid")' not in c
# Primary metadata fields directly in the header, bound to established save.
for key in ('noteDay','noteStatus','sourceURL','progressText'):
    assert '@Binding var '+key in c
    assert key+': $'+key in n
for name in ('dateButton','statusButton','sourceButton','progressButton','scheduleButton'):
    assert 'private var '+name+': some View {' in c
for key in ('noteDay','noteStatus','sourceURL'):
    assert '.onChange(of: '+key+')' in n
assert 'onAddProgress: addProgress' in n and 'onTrash: { confirmDelete = true }' in n
assert 'onRestore: { model.markDeleted(note, deleted: false) }' in n
# Contextual trash is confirmed and uses the fresh saved model note.
assert '.contextMenu {' in m and 'pendingTrashNote = note' in m
assert 'Button("메모 복원", systemImage: "arrow.uturn.backward")' in m
assert 'guard safeToChangeNote() else { return }' in m
assert 'MemoWeaverLayoutSwitchSafety.prepare()' in m
assert 'if let latest = model.notes.first(where: { $0.id == candidate.id && $0.deletedAt.isEmpty })' in m
assert 'model.markDeleted(latest, deleted: true)' in m
assert '.confirmationDialog("이 메모를 휴지통으로 이동하시겠습니까?"' in m
# The invisible placeholders do not intercept clicks; toolbar does not jump.
assert 'if fontSize > EditorTypographyRules.minimumSize {' in c
assert 'if fontSize < EditorTypographyRules.maximumSize {' in c
assert c.count('Color.clear.frame(width: buttonWidth,') == 2
assert c.count('.allowsHitTesting(false).accessibilityHidden(true)') == 2
assert 'disabled: fontSize <=' not in c and 'disabled: fontSize >=' not in c
# No refactor of the accepted split view, data store, or image attachment stack.
for file,expected in {
    'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
    'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
}.items():
    got=hashlib.sha256((w/file).read_bytes()).hexdigest()
    assert got==expected, f'Unexpected change to guarded subsystem: {file}'
print('PASS v0.9.31 source: responsive eight-tool toolbar, direct metadata, confirmed trash, hidden font bounds, protected subsystems')
PY
