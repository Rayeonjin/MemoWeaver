#!/bin/bash
# Stage-2 CommonMark/GFM nesting + contextual LaTeX/Mermaid helpers.
# Always uses synthetic content and disposable binaries; never user notes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d /tmp/memoryhome-markdown-stage2.XXXXXXXX)"
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
  "${PATHS[@]}" "$ROOT/Tests/MarkdownStage2Smoke.swift" -lsqlite3 -o "$TEMP/stage2"
"$TEMP/stage2"
# Catch missing source registrations and accidentally retired UI wiring.
grep -Fq 'MarkdownContextCore.context(in:' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'MarkdownIndentCore.change(in:' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'textViewDidChangeSelection' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'onContextChange:' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq 'MarkdownAssistSnippet.allCases' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq 'MarkdownListSyntax.render(' "$ROOT/WorkOSMac/MarkdownCore.swift"
if grep -Fq 'WorkOSBlockShelf(' "$ROOT/WorkOSMac/MainView.swift"; then
  echo 'Retired block editor unexpectedly found' >&2; exit 1
fi
echo 'PASS stage-2 editor/preview integration checks; full macOS app build still required.'
