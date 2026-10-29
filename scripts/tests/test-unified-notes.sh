#!/bin/bash
# Non-destructive migration regression. Uses throwaway SQLite databases only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
[[ "$(uname -s)" == Darwin ]] || { echo "Run on macOS with Apple Command Line Tools." >&2; exit 1; }
export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
SWIFTC="$(xcrun --sdk macosx --find swiftc)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
TEMP="$(mktemp -d /tmp/workos-unified.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
CORE=("$ROOT/WorkOSMac/Models.swift" "$ROOT/WorkOSMac/WorkBlocks.swift"
      "$ROOT/WorkOSMac/MemoryCore.swift" "$ROOT/WorkOSMac/MemoryRelationCore.swift" "$ROOT/WorkOSMac/MemoryTimelineCore.swift" "$ROOT/WorkOSMac/VirtualMemoryCore.swift" "$ROOT/WorkOSMac/PlannerCore.swift"
      "$ROOT/WorkOSMac/QuickCaptureCore.swift" "$ROOT/WorkOSMac/Storage.swift" "$ROOT/WorkOSMac/MemoWeaverAttachments.swift"
      "$ROOT/WorkOSMac/ArchiveDecoder.swift" "$ROOT/WorkOSMac/SearchEngine.swift"
      "$ROOT/WorkOSMac/TemplateCore.swift" "$ROOT/WorkOSMac/NotesListFilter.swift"
      "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" "$ROOT/WorkOSMac/MarkdownCore.swift" "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" "$ROOT/WorkOSMac/NoteDocuments.swift"
      "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift")
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    -sdk "$SDK" -target "${ARCH}-apple-macosx14.0" \
    "${CORE[@]}" "$ROOT/Tests/UnifiedPlainNotesSmoke.swift" -lsqlite3 -o "$TEMP/unified-test"
"$TEMP/unified-test"
# Checks editor routing and absence of retired MD entry point.
grep -Fq 'MarkdownNoteEditorScreen(' "$ROOT/WorkOSMac/MainView.swift"
# The legacy rich editor must not remain as dead SwiftUI code: Swift compiles
# unused view declarations too, and the old insert/help types were retired.
! grep -Fq 'struct NoteEditorScreen: View' "$ROOT/WorkOSMac/MainView.swift"
! grep -Fq 'WorkOSInsertPalette' "$ROOT/WorkOSMac/MainView.swift"
! grep -Fq 'WorkOSMarkdownHelp' "$ROOT/WorkOSMac/MainView.swift"
! grep -Fq 'Label("MD 메모"' "$ROOT/WorkOSMac/MainView.swift"
! grep -Fq 'createMarkdownNote()' "$ROOT/WorkOSMac/WorkOSApp.swift"
! grep -Fq 'WorkOSBlockShelf(' "$ROOT/WorkOSMac/MainView.swift"
[[ ! -f "$ROOT/WorkOSMac/WorkOSBlockViews.swift" ]]
grep -Fq 'return "```mermaid\n" + block.source' "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift"
grep -Fq 'convertLegacyBodyToMarkdown: migrating' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq 'snapshotBackupIfNeeded(force: true)' "$ROOT/WorkOSMac/Storage.swift"
grep -Fq '0.9.15' "$ROOT/WorkOSMac/Info.plist"
echo 'PASS one Markdown editor, legacy block shelf retired, source migration/backup guarded. Mac GUI and full build still require ./build.sh'
