#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d /tmp/memoryhome-md-stage4.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
PLATFORM=()
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARCH="$(uname -m)"
  PLATFORM=(-sdk "$SDK" -target "${ARCH}-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
fi
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library "${PLATFORM[@]}" \
  "$ROOT/WorkOSMac/Models.swift" \
  "$ROOT/WorkOSMac/QuickCaptureCore.swift" \
  "$ROOT/WorkOSMac/WorkBlocks.swift" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/WorkOSMac/MarkdownCore.swift" "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" \
  "$ROOT/WorkOSMac/EditorLineNumberRules.swift" \
  "$ROOT/Tests/MarkdownStage4Smoke.swift" -o "$TEMP/md-stage4"
"$TEMP/md-stage4"
# Verify the SwiftUI bridge to WKWebView contains every required event edge.
grep -Fq 'onCaretLineChange: (Int) -> Void' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'cachedLineStarts = EditorLineNumberRules.lineStarts(in:' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'previewCaretLine: $livePreviewCaretLine' "$ROOT/WorkOSMac/MainView.swift"
# Swift enforces labeled initializer argument ORDER, not just label presence.
# Regression guard: this call must pass previewHTML before previewCaretLine.
awk '
  /MarkdownNoteEditorScreen\(/ { inside=1; html=0; caret=0 }
  inside && /previewHTML: Binding\(/ { html=NR }
  inside && /previewCaretLine: \$livePreviewCaretLine/ { caret=NR }
  inside && /openPreview: \{/ {
    if (html > 0 && caret > html) { ok=1; exit }
    exit 1
  }
  END { if (!ok) exit 1 }
' "$ROOT/WorkOSMac/MainView.swift"
grep -Fq 'WorkOSSidePreviewPane(html: previewHTML,' "$ROOT/WorkOSMac/MainView.swift"
grep -Fq "document.querySelectorAll('[data-md-line]')" "$ROOT/WorkOSMac/WorkOSPreview.swift"
grep -Fq 'CTLineDraw(line, ctx)' "$ROOT/WorkOSMac/EditorLineNumberPainter.swift"
grep -Fq 'baselineOffset = defaultBaselineOffset' "$ROOT/WorkOSMac/EditorLineNumberPainter.swift"
if grep -Fq 'emptyRowBaselineOffset(' "$ROOT/WorkOSMac/EditorLineNumberPainter.swift"; then
  echo 'FAIL: obsolete neighboring baseline compensation' >&2; exit 1
fi
grep -Fq 'defaultBaselineOffset(for: font)' "$ROOT/WorkOSMac/EditorLineNumberPainter.swift"
grep -Fq 'storage.setAttributes(editor.typingAttributes,' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'article li ul,article li ol{padding-inline-start:1.15em;' "$ROOT/WorkOSMac/NoteDocuments.swift"
grep -Fq '.controlSize(.regular)' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
printf 'PASS v0.9.4 connected: caret focus, narrower nested lists, larger tool buttons, native gutter baselines\n'
