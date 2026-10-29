#!/bin/bash
# Cross-platform static invariants; actual SwiftUI/AppKit compiling needs macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EDITOR="$ROOT/WorkOSMac/RichEditor.swift"
TYPO="$ROOT/WorkOSMac/EditorTypography.swift"
PALETTE="$ROOT/WorkOSMac/MainView.swift"
CSS="$ROOT/WorkOSMac/RichHTMLColorStyles.swift"
grep -Fq 'super.paste(sender)' "$EDITOR"
grep -Fq 'EditorInk.adapt(storage, range: inserted)' "$EDITOR"
grep -Fq 'onChange(updated)' "$EDITOR"
grep -Fq 'RichHTMLColorStyles.inlineForegroundColors(in: html)' "$EDITOR"
grep -Fq 'EditorInk.adapt(display, range:' "$EDITOR"
grep -Fq 'case .ink:' "$EDITOR"
grep -Fq 'editor.setTextColor(color, range: range)' "$EDITOR"
grep -Fq 'case .automatic: return .labelColor' "$ROOT/WorkOSMac/EditorInk.swift"
# The palette was intentionally retired with the old HTML editor in v0.9.1.
grep -Fq 'MarkdownNoteEditorScreen(' "$PALETTE"
! grep -Fq 'WorkOSInkPalette(onPreset:' "$PALETTE"
grep -Fq 'ColorPicker("사용자 지정 색상"' "$ROOT/WorkOSMac/EditorInkPalette.swift"
grep -Fq 'let entire = NSRange(location: 0, length: output.length)' "$TYPO"
if grep -Eq 'output\.(removeAttribute|addAttribute)\(\.foregroundColor' "$TYPO"; then
    echo 'Typography is destroying user-selected ink' >&2
    exit 1
fi
# The only class-based CSS we can reuse is a validated foreground color.
grep -Fq 'let declaration = regex(' "$CSS"
printf 'PASS: legacy rich ink core preserved; inactive palette removed; unified Markdown editor routed\n'
