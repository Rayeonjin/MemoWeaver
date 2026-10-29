#!/bin/bash
# Optional synthetic parser benchmark, never a GUI/WebKit speed assertion.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-v55-bench.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
"$SWIFTC" -swift-version 5 -Onone -j 1 \
  "$ROOT/WorkOSMac/Models.swift" \
  "$ROOT/WorkOSMac/NotebookMembershipCore.swift" \
  "$ROOT/WorkOSMac/QuickCaptureCore.swift" \
  "$ROOT/WorkOSMac/WorkBlocks.swift" \
  "$ROOT/WorkOSMac/NotePreviewRules.swift" \
  "$ROOT/WorkOSMac/NoteDocuments.swift" "$ROOT/WorkOSMac/MemoWeaverAttachments.swift" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" "$ROOT/WorkOSMac/MarkdownCore.swift" \
  "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" \
  "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift" \
  "$ROOT/Tests/PreviewRenderBenchV0955.swift" \
  -o "$TMP/PreviewRenderBenchV0955"
"$TMP/PreviewRenderBenchV0955"
