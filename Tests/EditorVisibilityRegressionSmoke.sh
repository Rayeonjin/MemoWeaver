#!/bin/bash
# A zero-data-loss rollback guard for the blank NSTextView regression.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EDITOR="$ROOT/WorkOSMac/RichEditor.swift"
TYPO="$ROOT/WorkOSMac/EditorTypography.swift"
MAIN="$ROOT/WorkOSMac/MainView.swift"
# Stay on the original, native AppKit NSTextView drawing/autoresizing path.
grep -Fq 'let scroll = WorkOSTextWrappingScrollView()' "$EDITOR"
grep -Fq 'scroll.hasHorizontalScroller = false' "$EDITOR"
grep -Fq 'editor.minSize = NSSize(width: 0, height: 0)' "$EDITOR"
grep -Fq 'editor.autoresizingMask = [.width]' "$EDITOR"
grep -Fq 'editor.textContainer?.widthTracksTextView = true' "$EDITOR"
if grep -Eq 'WorkOSLineNumberRuler|rulersVisible|synchronizeEditorWidth' "$EDITOR"; then
  echo 'FAIL: v0.8.17 experimental gutter has returned' >&2; exit 1
fi
! test -e "$ROOT/WorkOSMac/EditorViewport.swift"
# Native paragraph wrap remains. No persisted note HTML or SQLite changes.
grep -Fq 'paragraph.lineBreakMode = .byWordWrapping' "$TYPO"
grep -Fq 'WorkOSUnifiedRightPane(' "$MAIN"
grep -Fq 'Text("미리보기").tag(NoteSidePaneTab.preview)' "$MAIN"
grep -Fq 'Text("참고 메모").tag(NoteSidePaneTab.reference)' "$MAIN"
grep -Fq 'MarkdownNoteEditorScreen(' "$MAIN"
grep -Fq 'MarkdownPlainEditor(' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
printf 'PASS unified native NSTextView active; legacy ruler/container forcing removed\n'
