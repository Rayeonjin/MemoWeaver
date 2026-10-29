#!/bin/bash
# v0.9.8: standalone, real Swift renderer + indentation tests. Uses synthetic data.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP="$(mktemp -d /tmp/memoryhome-memo.XXXXXXXX)"
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
  "${PATHS[@]}" "$ROOT/Tests/MarkdownMemoSmoke.swift" -lsqlite3 -o "$TEMP/memo-test"
"$TEMP/memo-test"
grep -Fq '@AppStorage(MarkdownPreviewMode.defaultsKey)' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq '@AppStorage(MarkdownPreviewMode.defaultsKey)' "$ROOT/WorkOSMac/MainView.swift"
grep -Fq 'mode: MarkdownPreviewMode? = nil' "$ROOT/WorkOSMac/NoteDocuments.swift"
grep -Fq '0.9.34' "$ROOT/WorkOSMac/Info.plist"
grep -Fq '<string>67</string>' "$ROOT/WorkOSMac/Info.plist"
echo 'PASS v0.9.14 source UI/export integration anchors; macOS GUI build required.'
