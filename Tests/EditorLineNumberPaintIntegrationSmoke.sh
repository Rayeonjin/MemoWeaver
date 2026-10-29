#!/bin/bash
# Guard the stable v0.8.19 TextKit geometry and the new narrow canvas path.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EDITOR="$ROOT/WorkOSMac/RichEditor.swift"
WRAP="$ROOT/WorkOSMac/EditorWrapViewport.swift"
CANVAS="$ROOT/WorkOSMac/EditorLineNumberCanvas.swift"
PAINTER="$ROOT/WorkOSMac/EditorLineNumberPainter.swift"
RULES="$ROOT/WorkOSMac/EditorLineNumberRules.swift"
grep -Fq 'let scroll = WorkOSTextWrappingScrollView()' "$EDITOR"
grep -Fq 'scroll.documentView = editor' "$EDITOR"
grep -Fq 'scroll.fitDocumentToViewport()' "$EDITOR"
grep -Fq 'editor.enableLineNumberPainting()' "$EDITOR"
grep -Fq 'editor.textContainerInset = NSSize(width: 50, height: 18)' "$EDITOR"
grep -Fq 'let canvas = WorkOSLineNumberCanvas(editor: self)' "$EDITOR"
grep -Fq 'addSubview(canvas)' "$EDITOR"
grep -Fq 'final class WorkOSLineNumberCanvas: NSView' "$CANVAS"
grep -Fq 'width: WorkOSLineNumberPainter.gutterWidth' "$CANVAS"
grep -Fq 'override func hitTest' "$CANVAS"
grep -Fq 'painter.draw(in: editor, dirtyRect: dirtyRect)' "$CANVAS"
grep -Fq 'NSTextStorage.didProcessEditingNotification' "$CANVAS"
grep -Fq 'NSView.boundsDidChangeNotification' "$CANVAS"
grep -Fq 'final class WorkOSLineNumberPainter' "$PAINTER"
grep -Fq 'EditorLineNumberRules.lineStarts(in: editor.string)' "$PAINTER"
# Empty rows must use their own TextKit fragment and the font's baseline,
# never a neighboring row's possibly different glyph metrics.
grep -Fq 'baselineOffset = defaultBaselineOffset' "$PAINTER"
grep -Fq 'fragment.minY + defaultBaselineOffset - numberFont.ascender' "$PAINTER"
if grep -Fq 'emptyRowBaselineOffset(' "$PAINTER"; then
  echo 'FAIL: neighboring row baseline estimate reintroduced' >&2; exit 1
fi
# Mac synthetic fixtures must have the same display-only normalization as
# MarkdownPlainEditor. Otherwise a passing/failing fixture proves little.
grep -Fq 'storage.setAttributes(editor.typingAttributes,' "$ROOT/Tests/EditorLineNumberBlankLineMacSmoke.swift"
grep -Fq 'static func lineStarts(in text: String)' "$RULES"
if grep -Eq 'addSubview|documentView[[:space:]]*=|NSRulerView|setFrameSize|containerSize[[:space:]]*=|textStorage\?\.setAttributedString|replaceCharacters|insertText' "$PAINTER" "$CANVAS"; then
  echo 'FAIL: line number render path may change scroll geometry or document' >&2; exit 1
fi
if grep -Eq 'lineNumberGutter|installLineNumbers|NSRulerView|rulersVisible|verticalRulerView' "$WRAP" "$EDITOR"; then
  echo 'FAIL: old scroll ruler or overlay regression introduced' >&2; exit 1
fi
if grep -Eq 'NSRulerView|rulersVisible|verticalRulerView|containerSize[[:space:]]*=' "$WRAP"; then
  echo 'FAIL: native scroll geometry changed' >&2; exit 1
fi
if grep -Fq 'override func draw(_ dirtyRect: NSRect)' "$EDITOR"; then
  echo 'FAIL: inline NSTextView painting path remains active' >&2; exit 1
fi
printf 'PASS independent 44pt inner gutter canvas; stable TextKit width, native document untouched\n'
