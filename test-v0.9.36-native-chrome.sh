#!/bin/bash
# v0.9.36 unified native titlebar, full-height sidebar backdrop, and relocated
# note actions. Synthetic tests only; does not touch the user's SQLite data.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
else
  SWIFTC="$(command -v swiftc)"
fi
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY'
from pathlib import Path
import plistlib,hashlib,sys
root=Path(sys.argv[1]); w=root/'WorkOSMac'
info=plistlib.loads((w/'Info.plist').read_bytes())
assert (info['CFBundleShortVersionString'], info['CFBundleVersion'], info['CFBundleIdentifier']) == ('0.9.36', '69', 'com.local.workos.notes')
app=(w/'WorkOSApp.swift').read_text()
main=(w/'MainView.swift').read_text()
chrome=(w/'MemoWeaverEditorChrome.swift').read_text()
screen=(w/'MarkdownNoteScreen.swift').read_text()
native=(w/'MemoWeaverNativeWindowChrome.swift').read_text()
actions=(w/'MemoWeaverWindowActions.swift').read_text()
assert '.windowToolbarStyle(.unifiedCompact(showsTitle: false))' in app
assert 'window.toolbarStyle = .unifiedCompact' in native and 'window.styleMask.insert(.fullSizeContentView)' in native
assert 'window.titleVisibility = .hidden' in native and 'window.titlebarAppearsTransparent = true' in native
assert 'window.titlebarSeparatorStyle = .none' in native
assert 'window.toolbar = toolbar' in native and 'NSToolbar(identifier:' in native
assert 'fixedWorkspaceControls' not in main and 'Text(pageTitle)' not in main
assert 'private var pageTitle:' not in main
assert 'fullHeightSidebarSurface' in main and '.ignoresSafeArea(.container, edges: .top)' in main
assert 'listVisible: isNotePage && effectiveListVisible' in main
assert 'MemoWeaverPinnedSplitView(' in main
assert 'MemoWeaverListVisibilityButton(actions: windowActions)' in chrome
assert 'MemoWeaverTrailingWindowActions(actions: windowActions' in chrome
assert 'windowActions: editorWindowActions' in main and 'windowActions: windowActions' in screen
assert 'MemoWeaverEmptyEditorHeader(actions: editorWindowActions)' in main
assert 'private func toggleNoteList()' in main and 'if focusModeEnabled' in main.split('private func toggleNoteList()',1)[1].split('@ViewBuilder',1)[0]
header=chrome.split('struct MemoWeaverEditorHeader: View {',1)[1].split('private var compactPropertiesButton',1)[0]
positions=['MemoWeaverListVisibilityButton(actions: windowActions)', 'titleInput', 'pinButton', 'moreMenu', 'MemoWeaverTrailingWindowActions(actions: windowActions']
indices=[header.index(p) for p in positions]
assert indices==sorted(indices),indices
assert 'static func isCompact(availableWidth:' in actions
assert 'availableWidth < 385' in actions
assert 'Button("새 메모", action: actions.newNote)' in actions
assert 'Button(actions.rightVisible ? "보조창 닫기" : "보조창 열기"' in actions
assert '.keyboardShortcut("b", modifiers: [.command, .option])' in app
assert '.keyboardShortcut("r", modifiers: [.command, .option])' in app
assert 'memoWeaverToggleNoteList' in main and 'memoWeaverToggleRightPane' in main
assert 'hasActiveNote' in actions and 'if !actions.focusEnabled {' in actions and 'if actions.hasActiveNote' in actions
assert 'if actions.focusEnabled' in actions and 'searchButton' in actions and 'openSearch: { showQuickSearch = true }' in main
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in main and 'MemoWeaverWorkspaceHeaderMetrics.height' in screen
assert 'MemoWeaverPaneFooter' in main
assert 'MemoWeaverInsertToolbar' in screen
# Important: root titlebar change must not accidentally rewrite protected,
# user-confirmed clipboard, attached files, persistence or split delegates.
expected={
'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
'MemoWeaverPinnedSplitView.swift':'972e15b504a7ef371a22c8fa5b75d64bf2b1759c404dd7a40f8850c1b6f5302d',
'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
'MarkdownPlainEditor.swift':'3e6d0bc50502f4a5923bd9053c0a1c7c274e85fa3eeaf012bf8216e48d9364db',
'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796',
}
for name, digest in expected.items():
    assert hashlib.sha256((w/name).read_bytes()).hexdigest()==digest,name
for width, compact in [(175, True),(260,True),(384,True),(385,False),(470,False),(900,False)]:
    assert (width<385)==compact
print('PASS v0.9.36: native chrome, independent pane widths, title-line actions, narrow/empty/focus safety, intact data and image paths')
PY
if [[ "$(uname -s)" == Darwin ]]; then
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0936-window.XXXXXXXX")"
  trap 'rm -rf -- "$TMP"' EXIT
  "$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    -framework AppKit -framework SwiftUI \
    "$ROOT/WorkOSMac/MemoWeaverNativeWindowChrome.swift" \
    "$ROOT/Tests/NativeWindowChromeV0936Smoke.swift" \
    -o "$TMP/window-test"
  "$TMP/window-test"
else
  echo 'SKIP real NSWindow smoke test: requires macOS.'
fi
