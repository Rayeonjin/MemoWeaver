#!/bin/bash
# v0.9.9: compile real Swift core + SQLite; synthetic notes only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d /tmp/memoryhome-virtual.XXXXXXXX)"
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
SOURCES=(Models.swift NotebookMembershipCore.swift QuickCaptureCore.swift WorkBlocks.swift MemoryCore.swift MemoryRelationCore.swift MemoryTimelineCore.swift VirtualMemoryCore.swift
  PlannerCore.swift Storage.swift MemoWeaverAttachments.swift ArchiveDecoder.swift SearchEngine.swift TemplateCore.swift
  NotesListFilter.swift MarkdownSyntaxCore.swift MarkdownCore.swift OfficialDiagramRuntime.swift
  NoteDocuments.swift LegacyNoteTextConverter.swift OllamaService.swift)
PATHS=()
for name in "${SOURCES[@]}"; do PATHS+=("$ROOT/WorkOSMac/$name"); done
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library "${PLATFORM[@]}" "${PATHS[@]}" \
  "$ROOT/Tests/VirtualMemorySmoke.swift" -lsqlite3 -o "$TMP/virtual-test"
"$TMP/virtual-test"
# AppKit/SwiftUI is validated by the Mac installer's CLT build only.
# Public creation/removal entrypoints retired; persisted virtual records remain.
if grep -Fq 'VirtualMemorySheet(' "$ROOT/WorkOSMac/MainView.swift"; then exit 1; fi
if grep -Fq 'VirtualMemorySheet(' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"; then exit 1; fi
grep -Fq 'virtualMemories: virtualMemories' "$ROOT/WorkOSMac/MemoryModel.swift"
# Query source extraction runs once before a cancellable detached search worker.
grep -Fq 'let texts = model.virtualSourceTexts()' "$ROOT/WorkOSMac/RecallScreens.swift"
grep -Fq 'virtualSourceTexts: texts' "$ROOT/WorkOSMac/RecallScreens.swift"
grep -Fq 'case "virtual": valid = liveVirtualHashes[item.id] == item.signature' "$ROOT/WorkOSMac/MemoryModel.swift"
echo 'PASS virtual memory source integration anchors (macOS GUI build still required)'
