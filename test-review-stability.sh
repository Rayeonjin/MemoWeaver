#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-stability.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SQL_FLAGS=()
if [[ "$(uname -s)" != Darwin ]]; then
  mkdir -p "$TMP/Modules/SQLite3"
  printf 'module SQLite3 [system] { header "/usr/include/sqlite3.h" link "sqlite3" export * }\n' > "$TMP/Modules/SQLite3/module.modulemap"
  SQL_FLAGS=(-I "$TMP/Modules")
fi
FILES=(Models Storage NotebookMembershipCore NotesListFilter WorkBlocks QuickCaptureCore
 MemoryCore MemoryRelationCore VirtualMemoryCore MemoWeaverAttachments PlannerCore
 MemoWeaverScheduleBackupPreflight LegacyNoteTextConverter MemoryTimelineCore
 NoteDraftRecovery MarkdownSyntaxCore)
SOURCES=()
for file in "${FILES[@]}"; do SOURCES+=("$ROOT/WorkOSMac/$file.swift"); done
swiftc -swift-version 5 ${SQL_FLAGS[@]+"${SQL_FLAGS[@]}"} -Onone -j 1 -lsqlite3 \
 "${SOURCES[@]}" "$ROOT/Tests/ReviewStabilitySmoke.swift" -o "$TMP/stability"
"$TMP/stability"
