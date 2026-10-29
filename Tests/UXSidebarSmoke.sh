#!/bin/bash
# Static regression checks for the retired separate quick-capture workspace.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
MAIN="$ROOT/WorkOSMac/MainView.swift"
MODEL="$ROOT/WorkOSMac/AppModel.swift"
APP="$ROOT/WorkOSMac/WorkOSApp.swift"
[[ ! -f "$ROOT/WorkOSMac/QuickCaptureView.swift" ]] || { echo 'Duplicate capture view remains' >&2; exit 1; }
if grep -Eq 'case capture|WorkspacePage.capture|\.capture|Toggle\("보관"|Button\("일반 편집기로"' "$MAIN" "$MODEL" "$APP"; then
  echo 'Retired capture/archive UI or routing remains' >&2; exit 1
fi
grep -Fq 'MarkdownNoteEditorScreen(' "$MAIN"
! grep -Fq 'WorkOSBlockShelf(' "$MAIN"
grep -Fq 'previewActive: sidePaneVisible && rightPaneTab == .preview' "$MAIN"
grep -Fq 'func newNoteFromShortcut() {' "$MODEL"
grep -Fq 'createNote(typeID: selectedPage.kindID ?? "type-note")' "$MODEL"
grep -Fq 'restoreLegacyArchivedNotesSafely()' "$MODEL"
grep -Fq 'restoreLegacyArchivedNotesSafely() throws -> Int' "$ROOT/WorkOSMac/Storage.swift"
grep -Fq 'case all, today, recent, pinned' "$ROOT/WorkOSMac/NotesListFilter.swift"
grep -Fq 'Label("노트북 · 종류"' "$MAIN"
grep -Fq 'Label("업무일지"' "$MAIN"
grep -Fq 'Label("검색"' "$MAIN"
grep -Fq 'Label("일정"' "$MAIN"
grep -Fq 'Label("메모"' "$MAIN"
grep -Fq '<string>0.9.5</string>' "$ROOT/WorkOSMac/Info.plist"
grep -Fq '<string>37</string>' "$ROOT/WorkOSMac/Info.plist"
printf 'PASS: unified navigation, one editor, no archive toggle, filters, version\n'
