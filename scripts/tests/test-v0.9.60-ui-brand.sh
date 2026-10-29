#!/bin/bash
# The Mac-specific GUI still needs live verification; this guards the source
# against anchor regressions, tooltip truncation and broken identity contracts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"
swiftc -frontend -parse -swift-version 5 WorkOSMac/*.swift
bash -n build.sh install.sh install-v0.9.60.sh
python3 - "$ROOT" <<'PY'
from pathlib import Path
import plistlib,sys
r=Path(sys.argv[1]);w=r/'WorkOSMac'
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert plist['CFBundleDisplayName']=='MemoWeaver'
assert plist['CFBundleExecutable']=='MemoWeaver'
assert plist['CFBundleIdentifier']=='com.local.workos.notes', 'UserDefaults domain changed!'
assert plist['CFBundleShortVersionString']=='0.9.60' and plist['CFBundleVersion']=='93'
bar=(w/'MemoWeaverEditorChrome.swift').read_text()
section=bar.split('struct MemoWeaverInsertToolbar: View {',1)[1].split('// Scratch/Notion-style quick table insertion.',1)[0]
assert 'ViewThatFits(in: .horizontal)' in section
# A parent-wide popover used to appear under the MIDDLE of the toolbar.
rootbody=section.split('private func tablePickerBinding(',1)[0]
assert '.popover(' not in rootbody, 'Full toolbar still owns the table popover'
assert 'tableGridOriginRow = visibleCount' in section
assert section.count('.popover(isPresented: tablePickerBinding(for: visibleCount)')==2, 'Table/overflow anchors missing'
assert 'attachmentAnchor: .rect(.bounds), arrowEdge: .bottom' in section
assert 'DispatchQueue.main.async {' in section, 'Overflow menu needs to dismiss first'
assert section.count('MemoWeaverHeaderIconSurface(height: 26)')>=5
for unexpected in ['formatButton(', 'headingMenu', 'MarkdownFormatCommand']:
 assert unexpected not in section,unexpected+' reintroduced'
tooltip=(w/'MemoWeaverPassiveTooltip.swift').read_text()
assert 'naturalWidth + 22' in tooltip and 'labelWidth - 10' in tooltip
assert 'label.maximumNumberOfLines = 0' in tooltip
assert 'panel.ignoresMouseEvents = true' in tooltip, 'First click must remain unblocked'
assert 'return event' in tooltip, 'Click event must be passed through'
assert '0.13' in tooltip
assert '[WorkOS]' not in (r/'build.sh').read_text()
assert 'MemoWeaver.app' in (r/'build.sh').read_text()
assert '-module-name MemoWeaver' in (r/'build.sh').read_text()
assert 'MacOS/MemoWeaver' in (r/'build.sh').read_text()
installer=(r/'install.sh').read_text()
assert 'pgrep -x MemoWeaver' in installer and 'pgrep -x WorkOS' in installer
assert 'MacOS/MemoWeaver' in installer
assert '기억의 집.app' in installer and 'WorkOS.app' in installer
assert '기존 WorkOS의 로컬 SQLite' not in (w/'MainView.swift').read_text()
store=(w/'Storage.swift').read_text()
assert 'appendingPathComponent("WorkOS", isDirectory: true)' in store
assert 'databaseURL = directory.appendingPathComponent("WorkOS.sqlite")' in store
assert 'private static let backupAppID = "memoweaver-notes"' in store
assert 'app == backupAppID || app == "workos-notes"' in store
assert 'Self.acceptsBackupApp(raw["app"])' in store
assert 'sourceSignature' in store and 'virtual_memories' in store
assert 'hasPrefix("MemoWeaver-") && $0.pathExtension' in store
assert 'Old WorkOS- snapshots are intentionally excluded from retention' in store
for filename in ('WorkOSApp.swift','MainView.swift','MemoWeaverEditorChrome.swift'):
 text=(w/filename).read_text()
 assert '"workos.appearance"' in text, 'Legacy appearance setting lost: '+filename
assert '"memoryhome.typography.fontSize"' in (w/'MainView.swift').read_text()
assert '"workos.ai.pendingNoteIDs"' in (w/'MemoryIdleModel.swift').read_text()
assert '"workos.notifications.revealDetails"' in (w/'MainView.swift').read_text()
assert '"workos.memory.threshold"' in (w/'AppModel.swift').read_text()
recovery=(w/'NoteDraftRecovery.swift').read_text()
assert 'appendingPathComponent("WorkOS", isDirectory: true)' in recovery
preview=(w/'MarkdownCore.swift').read_text()
assert 'case memo' in preview and 'case standard' in preview
assert 'if index > 0 { source += (mode == .memo || previousHardBreak)' in preview
print('PASS table popover anchored to trigger, no extra formatting controls')
print('PASS tooltip width reserve/no click swallowing')
print('PASS visible brand/executable and all legacy settings/data keys retained')
print('PASS dual JSON backup identity, old SQLite backups excluded from auto-pruning')
print('PASS memo vs standard Markdown preview semantics unchanged')
PY
