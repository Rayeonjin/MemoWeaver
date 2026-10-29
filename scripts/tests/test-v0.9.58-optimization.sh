#!/bin/bash
# v0.9.58 stabilization: insertion context, WKWebView patch safety and retired UI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw57-qa.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
"$SWIFTC" -swift-version 5 -Onone -j 1 \
  "$ROOT/WorkOSMac/Models.swift" \
  "$ROOT/WorkOSMac/NotebookMembershipCore.swift" \
  "$ROOT/WorkOSMac/QuickCaptureCore.swift" \
  "$ROOT/WorkOSMac/WorkBlocks.swift" \
  "$ROOT/WorkOSMac/NotePreviewRules.swift" \
  "$ROOT/WorkOSMac/NoteDocuments.swift" "$ROOT/WorkOSMac/MemoWeaverAttachments.swift" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" "$ROOT/WorkOSMac/MarkdownCore.swift" \
  "$ROOT/WorkOSMac/SlashCommandCore.swift" "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" \
  "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift" \
  "$ROOT/Tests/BlockInsertionV0956Helpers.swift" \
  "$ROOT/Tests/BlockInsertionImmediateV0956Smoke.swift" -o "$TMP/block-context"
"$TMP/block-context"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys,plistlib,hashlib
r=Path(sys.argv[1]); w=r/'WorkOSMac'
read=lambda n:(w/n).read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion']) == ('0.9.58','91')
editor=read('MarkdownPlainEditor.swift')
assert 'onContextChange(lastContext)' in editor
assert 'editor.window?.makeFirstResponder(editor)\n                coordinator.forceRefreshContext(in: editor)' in editor
assert 'self.forceRefreshContext(in: editor)' in editor
preview=read('WorkOSPreview.swift')
assert 'previousFormulae' in preview and 'previous.querySelector(\'math\')' in preview
assert "if (el.querySelector('math')) continue" in preview
assert 'previousDiagrams' in preview and 'window.__MWDiagramRefreshRunning' in preview
assert 'queuedHTML = html' in preview
main=read('MainView.swift'); chrome=read('MemoWeaverEditorChrome.swift'); note=read('MarkdownNoteScreen.swift')
app=read('WorkOSApp.swift'); search=read('MemoWeaverQuickSearchPalette.swift')
for old in ['importArchivesDialog()', 'importLegacyBackupDialog()', 'VirtualMemorySheet(']:
    assert old not in main, 'retired main UI leaks '+old
assert 'onVirtualMemory' not in chrome and 'onVirtualMemory' not in note
assert 'VirtualMemorySheet(' not in note
assert 'importArchivesDialog()' not in app and 'importLegacyBackupDialog()' not in app
assert 'case archives = ' not in search
# Original content/index remains in sqlite and in backup, even without UI.
store=read('Storage.swift')
assert 'CREATE TABLE IF NOT EXISTS virtual_memories' in store
assert 'SELECT id,name,text_content,line_count,added_at FROM archives' in store
assert '"sources": sources' in store and '"virtualSegments": virtualSegments' in store
assert 'func virtualMemories() throws -> [VirtualMemory]' in store
assert 'virtualMemories: virtualMemories' in read('MemoryModel.swift')
assert 'virtualSourceTexts: texts' in read('RecallScreens.swift')
# Reject unintended persistence / window / clipboard changes.
manifest=(r/'QA/v0.9.58-core-source.sha256').read_text().splitlines()
for row in manifest:
  digest,relative=row.split('  ',1)
  assert hashlib.sha256((r/relative).read_bytes()).hexdigest()==digest,relative+' was modified'
print('PASS 0.9.58: retired visible entrypoints, preserved SQLite/index/search/backup, no storage model changes')
PY
if command -v node >/dev/null 2>&1; then
  python3 - "$ROOT" "$TMP/patch.js" <<'PY'
from pathlib import Path
import sys
s=(Path(sys.argv[1])/'WorkOSMac/WorkOSPreview.swift').read_text()
script=s.split('private static let patchScript = #"""',1)[1].split('"""#',1)[0]
Path(sys.argv[2]).write_text('async function update(fragment) {\n'+script+'\n}\n')
PY
  node --check "$TMP/patch.js"
  echo 'PASS v0.9.58: incremental WebKit JavaScript syntax'
fi
