#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d /tmp/memoweaver-relations.XXXXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT
PLATFORM=()
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  PLATFORM=(-sdk "$SDK" -target "$(uname -m)-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
  mkdir -p "$TMP/SQLite3"
  printf 'module SQLite3 [system] { header "/usr/include/sqlite3.h" link "sqlite3" export * }\n' > "$TMP/SQLite3/module.modulemap"
  PLATFORM=(-I "$TMP")
fi
SOURCES=(Models.swift QuickCaptureCore.swift WorkBlocks.swift MemoryCore.swift MemoryRelationCore.swift MemoryTimelineCore.swift VirtualMemoryCore.swift
  PlannerCore.swift Storage.swift MemoWeaverAttachments.swift ArchiveDecoder.swift SearchEngine.swift TemplateCore.swift
  NotesListFilter.swift MarkdownSyntaxCore.swift MarkdownCore.swift OfficialDiagramRuntime.swift
  NoteDocuments.swift LegacyNoteTextConverter.swift OllamaService.swift)
PATHS=()
for name in "${SOURCES[@]}"; do PATHS+=("$ROOT/WorkOSMac/$name"); done
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library "${PLATFORM[@]}" "${PATHS[@]}" \
  "$ROOT/Tests/RelationMemorySmoke.swift" -lsqlite3 -o "$TMP/relationship-test"
"$TMP/relationship-test"
# macOS-only view/model entry points; full type-check is done on user's Mac.
grep -Fq 'func startRelationAnalysis(centerID:' "$ROOT/WorkOSMac/MemoryRelationModel.swift"
grep -Fq 'SideInferredRelationSection(centerID: centerID)' "$ROOT/WorkOSMac/SideMemoryPane.swift"
grep -Fq 'inferred: activeInferredRelations()' "$ROOT/WorkOSMac/MemoryModel.swift"
echo 'PASS v0.9.11 integration anchors (macOS SwiftUI build remains required)'
