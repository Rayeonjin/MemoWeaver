#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0965.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
FILES=(Models Storage NotebookMembershipCore NotesListFilter WorkBlocks QuickCaptureCore
 MemoryCore MemoryRelationCore VirtualMemoryCore MemoWeaverAttachments PlannerCore
 MemoWeaverScheduleBackupPreflight LegacyNoteTextConverter MemoryTimelineCore NoteDraftRecovery
 MarkdownSyntaxCore SearchEngine ArchiveDecoder MarkdownCore NotePreviewRules OfficialDiagramRuntime)
SOURCES=()
for file in "${FILES[@]}"; do SOURCES+=("$ROOT/WorkOSMac/$file.swift"); done
for test in UsabilityReleaseSmoke ReviewStabilitySmoke PlannerSmoke ScheduleReleaseV0963Smoke MultiNotebookSmoke BackupSmoke; do
  swiftc -swift-version 5 -Onone -j 1 -lsqlite3 "${SOURCES[@]}" "$ROOT/Tests/$test.swift" -o "$TMP/$test"
  "$TMP/$test"
done
