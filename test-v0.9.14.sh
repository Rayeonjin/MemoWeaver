#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0914.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
ARGS=(-swift-version 5 -Onone -j 1 -parse-as-library)
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARGS+=(-sdk "$SDK" -target "$(uname -m)-apple-macosx14.0")
else
  mkdir -p "$TMP/SQLite3"
  printf 'module SQLite3 [system] { header "/usr/include/sqlite3.h" link "sqlite3" export * }\n' > "$TMP/SQLite3/module.modulemap"
  ARGS+=(-I "$TMP")
fi
NAMES=(Models.swift QuickCaptureCore.swift WorkBlocks.swift MemoryCore.swift MemoryRelationCore.swift MemoryTimelineCore.swift ReferenceReaderCore.swift VirtualMemoryCore.swift PlannerCore.swift Storage.swift MemoWeaverAttachments.swift ArchiveDecoder.swift SearchEngine.swift TemplateCore.swift NotesListFilter.swift MarkdownSyntaxCore.swift MarkdownCore.swift OfficialDiagramRuntime.swift NoteDocuments.swift LegacyNoteTextConverter.swift OllamaService.swift)
SOURCES=()
for f in "${NAMES[@]}"; do SOURCES+=("$ROOT/WorkOSMac/$f"); done
"$SWIFTC" "${ARGS[@]}" "${SOURCES[@]}" "$ROOT/Tests/UnifiedMemoryV0914Smoke.swift" -lsqlite3 -o "$TMP/unified-test"
"$TMP/unified-test"
"$SWIFTC" -frontend -parse "$ROOT/WorkOSMac/ReferenceReaderWindow.swift" "$ROOT/WorkOSMac/MemoryIdleModel.swift" "$ROOT/WorkOSMac/SideMemoryPane.swift" "$ROOT/WorkOSMac/MainView.swift" >/dev/null
python3 - "$ROOT" <<'PY_CHECK'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); w=p/'WorkOSMac'
a=(w/'AppModel.swift').read_text()
m=(w/'MemoryModel.swift').read_text()
assert 'referenceReader.show(snapshot)' in m
assert 'func openMemoryEntityForEditing' in m
assert 'func openSource(_ source: MemorySource)' in a
assert 'openReferenceEntity(entity,' in a
assert 'backgroundRelationQueue.insert("note:" + noteID)' in (w/'MemoryIdleModel.swift').read_text()
assert 'func scheduleFullMemoryAnalysis' in (w/'MemoryIdleModel.swift').read_text()
assert '<string>0.9.35</string>' in (w/'Info.plist').read_text()
assert '<string>67</string>' in (w/'Info.plist').read_text()
print('PASS 0.9.14 AppKit integration anchors; full GUI compile still requires macOS')
PY_CHECK
