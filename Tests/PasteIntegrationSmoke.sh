#!/bin/bash
# Static wiring checks. The real Excel clipboard/UI/Undo flow must be checked on macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EDITOR="$ROOT/WorkOSMac/RichEditor.swift"
CORE="$ROOT/WorkOSMac/PasteTableCore.swift"
MAIN="$ROOT/WorkOSMac/MainView.swift"
APP="$ROOT/WorkOSMac/WorkOSApp.swift"

grep -Fq 'override func paste(_ sender: Any?)' "$EDITOR"
grep -Fq 'super.paste(sender)' "$EDITOR"
grep -Fq 'override func pasteAsPlainText(_ sender: Any?)' "$EDITOR"
grep -Fq 'super.pasteAsPlainText(sender)' "$EDITOR"
grep -Fq 'WorkOSPasteboardReader.tableText(from: clipboard)' "$EDITOR"
grep -Fq 'WorkOSPasteTable.preferredText(' "$EDITOR"
grep -Fq 'WorkOSPasteRecovery.replacementText(rich: pastedText, unicodePlain: unicodePlain)' "$EDITOR"
grep -Fq 'WorkOSPastedTypography.normalize(in: storage,' "$EDITOR"
grep -Fq 'onPasteRecoveryChange(true)' "$EDITOR"
# User-facing editor is MarkdownPlainEditor; legacy RichEditor remains
# available for compatibility but its paste affordance was retired.
grep -Fq 'MarkdownNoteEditorScreen(' "$MAIN"
grep -Fq 'WorkOSPasteTable.preferredText(plain:' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'WorkOSPasteTable.insertedRange' "$EDITOR"
grep -Fq 'WorkOSPasteTable.stillMatches' "$EDITOR"
grep -Fq 'editor.insertText(replacement, replacementRange: offer.range)' "$EDITOR"
grep -Fq 'editor.breakUndoCoalescing()' "$EDITOR"
grep -Fq 'DispatchQueue.main.async { [weak self, weak editor] in' "$EDITOR"
grep -Fq 'onPasteChoiceChange(true)' "$EDITOR"
grep -Fq 'case .convert: convertPendingPaste(in: editor)' "$EDITOR"
grep -Fq 'pasteGeneration += 1' "$EDITOR"
grep -Fq 'if !isPasting && !isUndoRedo && !editor.hasMarkedText()' "$EDITOR"
grep -Fq 'selectedRanges.count == 1' "$EDITOR"
grep -Fq 'enum WorkOSPasteTable' "$CORE"
grep -Fq 'htmlTableText(from html: String)' "$CORE"
grep -Fq 'MarkdownPasteCore.markdownTable(from:' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'override func pasteAsPlainText(_ sender: Any?)' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'struct RichTextEditor: NSViewRepresentable' "$EDITOR"
if grep -Eq 'CommandGroup\(replacing: \.pasteboard\)|commandsRemoved' "$APP"; then
  echo 'System paste commands unexpectedly overridden' >&2
  exit 1
fi
printf 'PASS: legacy rich paste core preserved; active unified editor converts Excel TSV/HTML to Markdown\n'
