#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-v060-brand.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SQL_FLAGS=()
if [[ "$(uname -s)" != Darwin ]]; then
  mkdir -p "$TMP/Modules/SQLite3"
  printf 'module SQLite3 [system] { header "/usr/include/sqlite3.h" link "sqlite3" export * }\n' > "$TMP/Modules/SQLite3/module.modulemap"
  SQL_FLAGS=(-I "$TMP/Modules")
fi
FILES=(Models.swift Storage.swift NotebookMembershipCore.swift NotesListFilter.swift
  WorkBlocks.swift QuickCaptureCore.swift MemoryCore.swift MemoryRelationCore.swift
  VirtualMemoryCore.swift MemoWeaverAttachments.swift PlannerCore.swift
  LegacyNoteTextConverter.swift MemoryTimelineCore.swift)
SOURCES=()
for f in "${FILES[@]}"; do SOURCES+=("$ROOT/WorkOSMac/$f"); done
swiftc -swift-version 5 ${SQL_FLAGS[@]+"${SQL_FLAGS[@]}"} -Onone -j 1 -lsqlite3 \
  "${SOURCES[@]}" "$ROOT/Tests/BrandBackupCompatibilityV0960.swift" -o "$TMP/brand-db"
"$TMP/brand-db" "$TMP/data"
