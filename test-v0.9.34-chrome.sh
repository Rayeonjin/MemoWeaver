#!/bin/bash
# v0.9.34: quiet neutral button language and identical explicit theme controls.
# This is a source/logic test, not a claim of macOS GUI pixel validation.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY'
from pathlib import Path
import plistlib,hashlib,re,sys
root=Path(sys.argv[1]); w=root/'WorkOSMac'
p=plistlib.loads((w/'Info.plist').read_bytes())
assert (p['CFBundleShortVersionString'],p['CFBundleVersion'],p['CFBundleIdentifier']) == ('0.9.35','68','com.local.workos.notes')
bar=(w/'MemoWeaverPaneFooter.swift').read_text()
chrome=(w/'MemoWeaverEditorChrome.swift').read_text()
main=(w/'MainView.swift').read_text()
# Matching, borderless, neutral treatment across the three pane footers.
assert 'static let height: CGFloat = 30' in bar and 'static let controlHeight: CGFloat = 26' in bar
assert 'struct MemoWeaverThemePicker: View' in bar
assert 'case system, light, dark' in bar
assert 'case threeButtons' in bar and 'case compactMenu' in bar
assert 'ForEach(MemoWeaverThemeOption.allCases)' in bar
assert 'selection = option.rawValue' in bar and 'selected: selection == option.rawValue' in bar
assert '.accessibilityValue(selection == option.rawValue' in bar
assert 'Color.primary.opacity(0.10)' in bar and 'Color.primary.opacity(0.065)' in bar
assert 'Color.accentColor' not in bar, 'Theme/button selection must not be system-blue'
assert '.strokeBorder(' not in bar, 'No permanent header outlines'
assert 'MemoWeaverThemePicker(selection: $appearance, scope: "앱"' in chrome
assert 'MemoWeaverThemePicker(selection: $previewAppearance, scope: "미리보기")' in main
assert '@AppStorage("workos.appearance")' in chrome
assert '@AppStorage("memoweaver.preview.appearance")' in main
assert 'appearance == "system" {' not in chrome, 'No cyclic light/dark toggle'
assert 'previewThemeButton(' not in main, 'No separate preview-only theme implementation'
# Normal editor has one-click 3-mode buttons; compact editor still has all 3 options.
status=chrome.split('struct MemoWeaverEditorStatusBar: View {',1)[1]
assert status.count('editorControls(presentation: .threeButtons') >= 2
assert status.count('editorControls(presentation: .compactMenu') >= 2
assert 'fixedSize(horizontal: true, vertical: false)' in status
assert 'fontSize > EditorTypographyRules.minimumSize' in status
assert 'fontSize < EditorTypographyRules.maximumSize' in status
assert status.count('Color.clear.frame(width: buttonWidth,') == 2
assert status.count('.allowsHitTesting(false).accessibilityHidden(true)') == 2
# Top-right icon actions are borderless and have the same hover/selected style.
pin=chrome.split('    private var pinButton: some View {',1)[1].split('    private var moreMenu:',1)[0]
more=chrome.split('    private var moreMenu: some View {',1)[1].split('\n}',1)[0]
assert 'MemoWeaverHeaderIconSurface(selected: pinned)' in pin
assert 'MemoWeaverHeaderIconSurface()' in more
assert 'MemoWeaverControlSurface()' not in pin+more
assert 'onTrash' in more and 'onRestore' in more and 'onExport' in more
# Workspace/aux tab visuals use the same surface; navigation actions preserved.
workspace=main.split('private var fixedWorkspaceControls: some View {',1)[1].split('private func toggleFocusMode()',1)[0]
for required in ('toggleNoteList', 'toggleFocusMode', 'model.newNoteFromShortcut()',
                 'setSidePaneVisible(!sidePaneVisible)', 'MemoWeaverHeaderIconSurface('):
    assert required in workspace, required
assert '.buttonStyle(.borderless)' not in workspace
right=main.split('private struct WorkOSUnifiedRightPane: View {',1)[1].split('private struct NoteListRow:',1)[0]
assert 'sideTab(.preview' in right and 'sideTab(.memory' in right and 'sideTab(.reference' in right
assert 'MemoWeaverHeaderIconSurface(selected: selectedTab == tab' in right
assert 'selectedTab = tab' in right
assert 'followPreviewCaret.toggle()' in right
assert 'MemoWeaverPaneFooter {' in main and 'MemoWeaverPaneFooterSurface()' in chrome
assert 'listFooter' in main and 'auxiliaryFooter' in main
# Protected, accepted subsystems: source bytes must stay identical to v0.9.33.
expected={
 'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
 'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
 'MemoWeaverPinnedSplitView.swift':'972e15b504a7ef371a22c8fa5b75d64bf2b1759c404dd7a40f8850c1b6f5302d',
 'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
}
for name,sha in expected.items():
    assert hashlib.sha256((w/name).read_bytes()).hexdigest()==sha,name
for name,sha in {
 'MarkdownPlainEditor.swift':'3e6d0bc50502f4a5923bd9053c0a1c7c274e85fa3eeaf012bf8216e48d9364db',
 'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
 'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796',
}.items():
    assert hashlib.sha256((w/name).read_bytes()).hexdigest()==sha,name
print('PASS v0.9.34 neutral UI controls, unified 3-mode themes, responsive fallback, protected app subsystems')
PY
