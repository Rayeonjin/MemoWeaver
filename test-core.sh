#!/bin/bash
# Core regression tests against a throwaway SQLite database, NOT real WorkOS notes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
[[ "$(uname -s)" == Darwin ]] || { echo 'Run this test on macOS with Apple Command Line Tools.' >&2; exit 1; }
export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
SWIFTC="$(xcrun --sdk macosx --find swiftc)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
TEMP="$(mktemp -d /tmp/workos-test.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
CORE=("$ROOT/WorkOSMac/Models.swift" "$ROOT/WorkOSMac/WorkBlocks.swift"
      "$ROOT/WorkOSMac/MemoryCore.swift" "$ROOT/WorkOSMac/MemoryRelationCore.swift" "$ROOT/WorkOSMac/MemoryTimelineCore.swift" "$ROOT/WorkOSMac/VirtualMemoryCore.swift" "$ROOT/WorkOSMac/PlannerCore.swift" "$ROOT/WorkOSMac/QuickCaptureCore.swift" "$ROOT/WorkOSMac/Storage.swift" "$ROOT/WorkOSMac/MemoWeaverAttachments.swift"
      "$ROOT/WorkOSMac/ArchiveDecoder.swift" "$ROOT/WorkOSMac/SearchEngine.swift"
      "$ROOT/WorkOSMac/TemplateCore.swift" "$ROOT/WorkOSMac/NotesListFilter.swift" "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift")
for caseName in CoreSmoke MemorySmoke TemplateSmoke PlannerSmoke QuickCaptureSmoke MultiCaptureSmoke UXConsolidationSmoke HTMLPreviewSmoke BackupSmoke; do
  printf '[WorkOS] Testing %s (temporary SQLite)\n' "$caseName"
  "$SWIFTC" -swift-version 5 -Onone -sdk "$SDK" -target "${ARCH}-apple-macosx14.0" \
      "${CORE[@]}" "$ROOT/Tests/$caseName.swift" -lsqlite3 -o "$TEMP/$caseName"
  "$TEMP/$caseName" "$ROOT/Tests/legacy_cp949_no_extension"
done
printf '[기억의 집] Testing typography rules (shared Korean editor settings)\n'
"$SWIFTC" -swift-version 5 -Onone -sdk "$SDK" -target "${ARCH}-apple-macosx14.0" \
    "$ROOT/WorkOSMac/EditorTypographyRules.swift" "$ROOT/Tests/TypographySmoke.swift" \
    -o "$TEMP/TypographySmoke"
"$TEMP/TypographySmoke"
printf '[기억의 집] Testing paste TSV/UTF-16 safety rules\n'
"$SWIFTC" -swift-version 5 -Onone -sdk "$SDK" -target "${ARCH}-apple-macosx14.0" \
    "$ROOT/WorkOSMac/PasteTableCore.swift" "$ROOT/Tests/PasteTableSmoke.swift" \
    -o "$TEMP/PasteTableSmoke"
"$TEMP/PasteTableSmoke"
printf '[WorkOS] Foundation and SQLite smoke tests passed.\n'
