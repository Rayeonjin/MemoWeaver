#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EDITOR="$ROOT/WorkOSMac/RichEditor.swift"
WRAP="$ROOT/WorkOSMac/EditorWrapViewport.swift"
TYPO="$ROOT/WorkOSMac/EditorTypography.swift"
MAIN="$ROOT/WorkOSMac/MainView.swift"
grep -Fq 'let scroll = WorkOSTextWrappingScrollView()' "$EDITOR"
grep -Fq 'scroll.fitDocumentToViewport()' "$EDITOR"
grep -Fq 'editor.textContainer?.widthTracksTextView = true' "$EDITOR"
grep -Fq 'editor.textContainer?.heightTracksTextView = false' "$EDITOR"
grep -Fq 'editor.isHorizontallyResizable = false' "$EDITOR"
grep -Fq 'scroll.hasHorizontalScroller = false' "$EDITOR"
if grep -Fq 'editor.textContainer?.containerSize =' "$EDITOR"; then
  echo 'FAIL: fixed container width reintroduced' >&2; exit 1
fi
grep -Fq 'override func layout()' "$WRAP"
grep -Fq 'contentView.bounds.width' "$WRAP"
grep -Fq 'editor.setFrameSize(NSSize(width: viewportWidth,' "$WRAP"
if grep -Eq '^ *[[:alnum:]_?]+\.containerSize[[:space:]]*=|NSRulerView|textStorage\?\.setAttributedString' "$WRAP"; then
  echo 'FAIL: layout code touches container dimensions, ruler or text' >&2; exit 1
fi
grep -Fq 'paragraph.lineBreakMode = .byWordWrapping' "$TYPO"
grep -Fq 'WorkOSUnifiedRightPane(' "$MAIN"
grep -Fq 'Text("미리보기").tag(NoteSidePaneTab.preview)' "$MAIN"
grep -Fq 'Text("참고 메모").tag(NoteSidePaneTab.reference)' "$MAIN"
echo 'PASS current split viewport tracks editor width; no ruler, forced container or storage writes'
