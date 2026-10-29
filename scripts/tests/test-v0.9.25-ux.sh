#!/bin/bash
# Pure source/parser regression for the single activity rail and stable header width.
# Never opens user's notes/database, never installs the app.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
"$(command -v swiftc)" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY_CHECK'
import plistlib,re,sys
from pathlib import Path
r=Path(sys.argv[1]); w=r/'WorkOSMac'
a=(w/'WorkOSApp.swift').read_text();m=(w/'MainView.swift').read_text()
c=(w/'MemoWeaverEditorChrome.swift').read_text();n=(w/'MarkdownNoteScreen.swift').read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier']) == ('0.9.35','68','com.local.workos.notes')
# No dual shell, toolbar switch, persisted legacy toggle, or old settings checkbox.
assert 'compactNavigationEnabled' not in m+a
assert 'memoweaver.ui.compactNavigationEnabled' not in m+a
assert 'NavigationSplitView(' not in m
assert 'legacyShell' not in m and 'switchNavigationLayout' not in m
assert '간결한 아이콘 탐색 사용' not in m
assert '간결한 탐색 화면으로 바꾸기' not in m+a
assert '.keyboardShortcut("0", modifiers: [.command, .option])' not in a
assert 'private var activityRail: some View {' in m and '.frame(width: 52)' in m
assert '.onHover { hovered in' in m and 'Text(title)' in m
# Focus keeps its independent shortcut and synchronous IME/save protection.
assert '.keyboardShortcut("f", modifiers: [.command, .option])' in a
assert 'guard MemoWeaverLayoutSwitchSafety.prepare() else {' in m
assert 'focusModeEnabled.toggle()' in m
assert 'memoWeaverBeforeLayoutChange' in n and 'flush(checkpoint: false)' in n
assert 'effectiveListVisible' in m and 'effectiveRightPaneVisible' in m
assert 'NoteSidePaneRules.isVisibleForLayout(' in m and 'compactNavigation: true' in m
# The v0.9.35 header retains fixed classification widths, while the
# trailing more action is a compact 32pt target and narrow layouts collapse.
for name,val in [('bookWidth',142),('typeWidth',132),('pinWidth',32),('moreWidth',32)]:
    assert re.search(r'static let '+name+r': CGFloat = '+str(val)+r'\b',c),name
for name in ['pinWidth','moreWidth']:
    assert '.frame(width: Metrics.'+name+')' in c,name
assert 'notebookMenu(width: Metrics.bookWidth)' in c
assert 'typeMenu(width: Metrics.typeWidth)' in c
assert 'compactClassificationMenu' in c and 'compactPropertiesButton' in c
assert 'ViewThatFits(in: .horizontal)' in c
assert '.truncationMode(.tail)' in c
assert 'bookID = item.id' in c and 'typeID = item.id' in c and 'pinned.toggle()' in c
assert 'TextField(fallbackTitle, text: $title)' in c
# Focus/rail changes never alter persistence, Mermaid, or parsing features.
assert 'MemoWeaverPinnedSplitView(' in m and 'NotesNavigationListView()' in m
assert 'test-v0.9.25-ux.sh' in (r/'install-v0.9.25.sh').read_text()
print('PASS 0.9.25 UX contracts: one rail, reversible focus, fixed menus and narrow fallback, original editor/data behavior')
PY_CHECK
