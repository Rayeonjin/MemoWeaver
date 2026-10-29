#!/bin/bash
# v0.9.61: offline source insertion + actual Markdown render smoke.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-toolkit-61.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
swiftc -swift-version 5 -Onone -j 1 \
  "$ROOT/WorkOSMac/Models.swift" \
  "$ROOT/WorkOSMac/NotebookMembershipCore.swift" \
  "$ROOT/WorkOSMac/QuickCaptureCore.swift" \
  "$ROOT/WorkOSMac/WorkBlocks.swift" \
  "$ROOT/WorkOSMac/NotePreviewRules.swift" \
  "$ROOT/WorkOSMac/NoteDocuments.swift" \
  "$ROOT/WorkOSMac/MemoWeaverAttachments.swift" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/WorkOSMac/MarkdownCore.swift" \
  "$ROOT/WorkOSMac/MemoWeaverInsertCatalog.swift" \
  "$ROOT/WorkOSMac/SlashCommandCore.swift" \
  "$ROOT/WorkOSMac/MarkdownSlashContextCore.swift" \
  "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" \
  "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift" \
  "$ROOT/Tests/BlockInsertionV0956Helpers.swift" \
  "$ROOT/Tests/InsertCatalogV0961Smoke.swift" -o "$TMP/toolkit"
"$TMP/toolkit"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import hashlib, plistlib, sys
r=Path(sys.argv[1]); w=r/'WorkOSMac'
ui=(w/'MemoWeaverEditorChrome.swift').read_text()
section=ui.split('struct MemoWeaverInsertToolbar: View {',1)[1].split('// Scratch/Notion-style quick table insertion.',1)[0]
assert 'ViewThatFits(in: .horizontal)' in section
assert '.table, .code, .equation, .mermaid, .markmap, .chart, .diagram, .callout, .footnote' in section
assert 'advancedSyntaxMenu' in section and 'MemoWeaverCodeTemplates.allCases' in section
assert 'MemoWeaverMarkdownExtras.items(group)' in section
assert section.count('.popover(isPresented: tablePickerBinding(for: visibleCount)')==2
assert 'attachmentAnchor: .rect(.bounds), arrowEdge: .bottom' in section
for reject in ['formatButton(', 'headingMenu', 'onFormat', 'case .bold', 'case .italic']:
 assert reject not in section, reject
view=(w/'MarkdownNoteScreen.swift').read_text()
assert 'onInsertAdvanced:' in view and 'MemoWeaverDiagramExtraTools.items(for: context)' in view
assert 'onInsertCode:' in view and 'onInsertExtra:' in view
assert 'editorContext == .normal || editorContext == .code' in view
passive=(w/'MemoWeaverPassiveTooltip.swift').read_text()
assert 'MemoWeaverTooltipContentView' in passive
assert 'horizontalPadding: CGFloat = 10' in passive
assert 'message.draw(with: rect, options:' in passive
assert 'NSAttributedString(string: message' in passive
assert 'label.frame' not in passive and 'naturalWidth + 22' not in passive
assert 'panel.ignoresMouseEvents = true' in passive and 'return event' in passive
assert 'static let hoverDelay: TimeInterval = 0.13' in passive
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion']) == ('0.9.61','94')
assert plist['CFBundleIdentifier']=='com.local.workos.notes', 'existing settings identity must not change'
for row in (r/'QA/v0.9.60-core-source.sha256').read_text().splitlines():
 digest,name = row.split('  ',1)
 assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest, name + ' changed'
print('PASS v0.9.61: compact editor toolbar, attached table picker, tooltip exact layout and click-through')
print('PASS v0.9.61: storage/model/attachments/virtual indexes/window geometry hash-unchanged')
PY
