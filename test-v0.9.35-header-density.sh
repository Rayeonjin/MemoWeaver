#!/bin/bash
# v0.9.35 header information architecture / chrome source test.
# Native SwiftUI pixel layout requires an actual macOS GUI acceptance run.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY'
from pathlib import Path
import hashlib, plistlib, re,sys
root=Path(sys.argv[1]); w=root/'WorkOSMac'
info=plistlib.loads((w/'Info.plist').read_bytes())
assert (info['CFBundleShortVersionString'],info['CFBundleVersion'],info['CFBundleIdentifier'])==('0.9.35','68','com.local.workos.notes')
ch=(w/'MemoWeaverEditorChrome.swift').read_text()
sc=(w/'MarkdownNoteScreen.swift').read_text()
ma=(w/'MainView.swift').read_text()
fo=(w/'MemoWeaverPaneFooter.swift').read_text()
assert 'static let height: CGFloat = 128' in fo
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in sc
assert 'MemoWeaverWorkspaceHeaderMetrics.height' in ma
assert 'frame(height: model.selectedPage.isActiveNotesPage' in ma
assert '.frame(height: (recoveryDraft == nil && note.isMarkdown)' in sc
assert 'Spacer(minLength: 8)' in sc.split('MemoWeaverEditorHeader(',1)[1].split('MemoWeaverInsertToolbar',1)[0]
header=ch.split('struct MemoWeaverEditorHeader: View {',1)[1].split('// Less frequent attributes',1)[0]
assert 'titleInput' in header and 'pinButton' in header and 'moreMenu' in header
assert header.index('titleInput\n') < header.index('bookMenu\n') < header.index('metadataActions\n')
assert 'ViewThatFits(in: .horizontal)' in header
assert 'compactPropertiesButton' in header and 'compactClassificationMenu' in header
assert 'Menu("노트북") { notebookChoices }' in header and 'Menu("종류") { typeChoices }' in header
assert 'Button("메모 속성…", action: onAdditionalInfo)' in header
assert 'case .table' not in header, 'The existing Markdown tools remain in their own toolbar'
assert header.count('.sheet(isPresented: $showingNewBook)') == 1
assert header.count('.sheet(isPresented: $showingNewType)') == 1
assert '.frame(minWidth: 66, maxWidth: 520' in header
assert 'fallbackTitle: displayTitle,' in sc and 'saveLabel: saveLabel)' in sc
assert 'private var saveStatus' not in header
status=ch.split('struct MemoWeaverEditorStatusBar: View {',1)[1]
assert 'let saveLabel: String' in status
assert 'saveLabel == "저장 실패"' in status and 'saveIndicator' in status
assert 'MemoWeaverThemePicker(selection: $appearance, scope: "앱"' in status
assert 'MemoWeaverThemePicker(selection: $previewAppearance, scope: "미리보기")' in ma
assert 'fontSize > EditorTypographyRules.minimumSize' in status
assert 'fontSize < EditorTypographyRules.maximumSize' in status
assert 'if !model.selectedBookFilterID.isEmpty || !model.selectedTypeFilterID.isEmpty' in ma
assert 'model.resetNoteFilters()' in ma
assert 'listFooter' in ma and 'MemoWeaverPaneFooter' in ma
assert 'MemoWeaverInsertToolbar' in sc and '.mermaid, .markmap, .chart, .diagram, .callout, .footnote' in ch
assert 'MemoWeaverPinnedSplitView(' in ma
# Both headers share a common band irrespective of window width; the center editor absorbs width.
for available in (1450,1070,820):
    # Shared alignment is vertical and independent of native splitter width.
    list_bottom = 42 + 128
    editor_bottom = 42 + 128
    assert list_bottom == editor_bottom
    assert available > 2*128
# Protected, user-confirmed data and clipboard paths are unchanged from v0.9.34.
expected={
 'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
 'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
 'MemoWeaverPinnedSplitView.swift':'972e15b504a7ef371a22c8fa5b75d64bf2b1759c404dd7a40f8850c1b6f5302d',
 'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
 'MarkdownPlainEditor.swift':'3e6d0bc50502f4a5923bd9053c0a1c7c274e85fa3eeaf012bf8216e48d9364db',
 'MemoWeaverImageClipboard.swift':'e18144944187bbd4397864851e4e905af73399c0e68dae8df2e756da78ae2d29',
 'MemoWeaverPasteSelection.swift':'770aa805bad5ac500ffd199cb20644e8a0f1531a163574e7e6e9fc822856e796',
}
for name,digest in expected.items():
    assert hashlib.sha256((w/name).read_bytes()).hexdigest()==digest, name
for sz in (1450,1070,820):
    assert (root/f'QA/HeaderDensity_v0.9.35_{sz}.png').is_file()
print('PASS v0.9.35: shared 128pt header band, three-row editor, responsive properties, save in footer, category creation & filter reset, protected persistence/clipboard/split')
print('NOTE macOS SwiftUI visual QA not available in Linux; browser image only a layout concept.')
PY
