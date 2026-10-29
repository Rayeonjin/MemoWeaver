#!/bin/bash
# Static checks validate wiring, not an actual Mac GUI/table edit.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EDITOR="$ROOT/WorkOSMac/RichEditor.swift"
MAIN="$ROOT/WorkOSMac/MainView.swift"
NATIVE="$ROOT/WorkOSMac/NativeTableConversion.swift"
grep -Fq 'func textViewDidChangeSelection(_ notification: Notification)' "$EDITOR"
grep -Fq 'WorkOSNativeTableConversion.cursorIsInsideTable' "$EDITOR"
grep -Fq 'WorkOSNativeTableConversion.offer' "$EDITOR"
grep -Fq 'editor.insertText(replacement, replacementRange: offer.range)' "$EDITOR"
grep -Fq 'editor.breakUndoCoalescing()' "$EDITOR"
# The rich-text table UI was removed; in the unified Markdown editor, paste
# converts spreadsheet cells to Markdown source, not native NSTextTable cells.
grep -Fq 'MarkdownNoteEditorScreen(' "$MAIN"
grep -Fq 'MarkdownPasteCore.markdownTable(from:' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'block.table === table' "$NATIVE"
grep -Fq 'let cellText' "$NATIVE" || grep -Fq 'var cellText' "$NATIVE"
if grep -Eq 'removeAll\(|DELETE FROM notes' "$NATIVE"; then
    echo 'Native table conversion must not change note tables/storage' >&2
    exit 1
fi
printf 'PASS: legacy NSTextTable conversion core retained; unified editor uses Markdown table paste\n'
