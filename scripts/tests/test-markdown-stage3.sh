#!/bin/bash
# Stage 3 input palette + screenshot-inspired empty-line gutter assertions.
# Uses synthetic data only. AppKit pixel/geometry checks run on macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP="$(mktemp -d /tmp/memoryhome-md-stage3.XXXXXXXX)"
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
  mkdir -p "$TEMP/SQLite3"
  printf 'module SQLite3 [system] { header "/usr/include/sqlite3.h" link "sqlite3" export * }\n' > "$TEMP/SQLite3/module.modulemap"
  PLATFORM=(-I "$TEMP")
fi
SOURCES=(Models.swift QuickCaptureCore.swift WorkBlocks.swift MemoryCore.swift MemoryRelationCore.swift MemoryTimelineCore.swift VirtualMemoryCore.swift
  PlannerCore.swift Storage.swift MemoWeaverAttachments.swift ArchiveDecoder.swift SearchEngine.swift
  TemplateCore.swift NotesListFilter.swift MarkdownSyntaxCore.swift
  MarkdownCore.swift OfficialDiagramRuntime.swift NoteDocuments.swift LegacyNoteTextConverter.swift)
PATHS=()
for source in "${SOURCES[@]}"; do PATHS+=("$ROOT/WorkOSMac/$source"); done
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library "${PLATFORM[@]}" \
  "${PATHS[@]}" "$ROOT/Tests/MarkdownStage3Smoke.swift" -lsqlite3 -o "$TEMP/stage3"
"$TEMP/stage3"
grep -Fq 'MarkdownAssistPalette(context:' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq 'MarkdownAssistInsertionCore.prepare(' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'CTLineDraw(line, ctx)' "$ROOT/WorkOSMac/EditorLineNumberPainter.swift"
if grep -Fq 'neighboringOffset(for:' "$ROOT/WorkOSMac/EditorLineNumberPainter.swift"; then echo 'FAIL stale blank-line baseline correction' >&2; exit 1; fi
if [[ "$(uname -s)" == Darwin ]]; then
  "$ROOT/scripts/tests/test-line-numbers.sh"
else
  echo 'SKIP native AppKit blank-line rendering (macOS only)'
fi
