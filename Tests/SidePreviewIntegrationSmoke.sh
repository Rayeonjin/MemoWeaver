#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
MAIN="$ROOT/WorkOSMac/MainView.swift"
MODEL="$ROOT/WorkOSMac/AppModel.swift"
PREVIEW="$ROOT/WorkOSMac/WorkOSPreview.swift"
DOCS="$ROOT/WorkOSMac/NoteDocuments.swift"
# Use a typed category route and the existing notes table/filter. Do not build
# a parallel store or edit the SQLite schema.
grep -Fq 'case kind(String)' "$MODEL"
grep -Fq 'selectedPage.kindID ?? selectedTypeFilterID' "$MODEL"
grep -Fq 'NotesListFilter.matches(note' "$MODEL"
grep -Fq 'case .kind(let id)' "$MAIN"
grep -Fq 'railButton(.memory, title: "기억 지도"' "$MAIN"
grep -Fq 'private var typeFilter: some View' "$MAIN"
grep -Fq 'let selectedType = selectedPage.kindID ??' "$MODEL"
# Preview must be a side pane fed by current editor state and never save on its own.
# The main toolbar (not the editor header) is the only panel toggle.
grep -Fq 'setSidePaneVisible(!sidePaneVisible)' "$MAIN"
grep -Fq 'WorkOSUnifiedRightPane(' "$MAIN"
grep -Fq 'private struct WorkOSUnifiedRightPane: View' "$MAIN"
grep -Fq 'Text("미리보기").tag(NoteSidePaneTab.preview)' "$MAIN"
grep -Fq 'Text("참고 메모").tag(NoteSidePaneTab.reference)' "$MAIN"
grep -Fq '.pickerStyle(.segmented)' "$MAIN"
grep -Fq 'ReferenceWorkspacePane(currentNoteID: currentNoteID' "$MAIN"
grep -Fq 'WorkOSHTMLPreview(html: renderedHTML' "$ROOT/WorkOSMac/ReferenceWorkspacePane.swift"
grep -Fq 'WorkOSSidePreviewPane(html: previewHTML,' "$MAIN"
grep -Fq 'previewActive: effectiveRightPaneVisible && rightPaneTab == .preview' "$MAIN"
grep -Fq 'livePreviewNoteID == model.selectedNoteID ? livePreviewHTML : ""' "$MAIN"
grep -Fq 'onChange(of: previewActive)' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq '@AppStorage("memoweaver.rightPane.activeTab")' "$MAIN"
grep -Fq '@AppStorage("memoweaver.rightPane.visibility")' "$MAIN"
grep -Fq 'MemoWeaverPinnedSplitView(' "$MAIN"
grep -Fq 'MemoWeaverPinnedPaneLayout.resolved(' "$ROOT/WorkOSMac/MemoWeaverPinnedSplitView.swift"
# The single right-panel toggle owns both open and close; no duplicate X in the pane.
! grep -Fq 'onClose: { setSidePaneVisible(false) }' "$MAIN"
if grep -Eq 'referencePaneVisible|previewVisible\.toggle\(\)|previewBinding\(' "$MAIN"; then
  echo 'FAIL: duplicate editor/reference pane control remains' >&2
  exit 1
fi
grep -Fq 'NoteDocuments.markdownPreviewHTML(' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq 'Task.sleep(nanoseconds: 550_000_000)' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq 'WKWebViewConfiguration()' "$PREVIEW"
grep -Fq '.nonPersistent()' "$PREVIEW"
grep -Fq 'func webView(_ webView: WKWebView, decidePolicyFor navigationAction:' "$PREVIEW"
# v0.9.1: all notes use Markdown source. Old bottom block shelf is gone.
[[ ! -f "$ROOT/WorkOSMac/WorkOSBlockViews.swift" ]]
! grep -Fq 'WorkOSBlockShelf(' "$MAIN"
grep -Fq 'MarkdownNoteEditorScreen(' "$MAIN"
grep -Fq 'return "```mermaid\n" + block.source' "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift"
grep -Fq 'return "$$\n" + block.source' "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift"
grep -Fq 'return wrappingHTML(title: title' "$DOCS"
# No migration or user DB rewrite in this update.
if grep -Eq 'DROP TABLE|DELETE FROM notes|UPDATE notes' "$ROOT/WorkOSMac/NotePreviewRules.swift"; then
  exit 1
fi
printf 'PASS unified Markdown editor + side preview/reference tabs; legacy shelf removed\n'
