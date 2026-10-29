#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0917.XXXXXXXX")"
trap 'rm -rf -- "$TEMP"' EXIT
SWIFTC="$(command -v swiftc)"
ARGS=(-swift-version 5 -Onone -j 1 -parse-as-library)
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARGS+=(-sdk "$SDK" -target "$(uname -m)-apple-macosx14.0")
else
  mkdir -p "$TEMP/SQLite3"
  printf 'module SQLite3 [system] { header "/usr/include/sqlite3.h" link "sqlite3" export * }\n' > "$TEMP/SQLite3/module.modulemap"
  ARGS+=(-I "$TEMP")
fi
NAMES=(Models.swift QuickCaptureCore.swift WorkBlocks.swift MemoryCore.swift MemoryRelationCore.swift MemoryTimelineCore.swift ReferenceReaderCore.swift ReferencePanelCore.swift VirtualMemoryCore.swift PlannerCore.swift Storage.swift MemoWeaverAttachments.swift ArchiveDecoder.swift SearchEngine.swift TemplateCore.swift NotesListFilter.swift MarkdownSyntaxCore.swift MarkdownCore.swift OfficialDiagramRuntime.swift NoteDocuments.swift LegacyNoteTextConverter.swift OllamaService.swift)
SOURCES=()
for f in "${NAMES[@]}"; do SOURCES+=("$ROOT/WorkOSMac/$f"); done
"$SWIFTC" "${ARGS[@]}" "${SOURCES[@]}" "$ROOT/Tests/QualityV0917Smoke.swift" -lsqlite3 -o "$TEMP/qa-test"
"$TEMP/qa-test"
"$SWIFTC" "${ARGS[@]}" "$ROOT/WorkOSMac/NoteDraftRecovery.swift" "$ROOT/Tests/DraftRecoveryV0917Smoke.swift" -o "$TEMP/draft-test"
"$TEMP/draft-test"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT/WorkOSMac" <<'PY'
from pathlib import Path
import sys
w=Path(sys.argv[1]); main=(w/'MainView.swift').read_text(); app=(w/'WorkOSApp.swift').read_text()
ref=(w/'ReferenceWorkspacePane.swift').read_text(); search=(w/'RecallScreens.swift').read_text()
note=(w/'MarkdownNoteScreen.swift').read_text(); db=(w/'Storage.swift').read_text()
assert '<string>0.9.35</string>' in (w/'Info.plist').read_text()
assert '<string>67</string>' in (w/'Info.plist').read_text()
assert 'com.local.workos.notes' in (w/'Info.plist').read_text()
assert 'private var fixedWorkspaceControls: some View' in main
assert 'private var activityRail: some View' in main
assert 'railButton(.settings' in main and 'railButton(.all' in main
assert 'ToolbarItemGroup(placement: .primaryAction)' not in main
assert 'setSidePaneVisible(!sidePaneVisible)' in main
assert 'Window("MemoWeaver", id: "main")' in app
assert '.keyboardShortcut("f", modifiers: [.command, .shift])' in app
assert 'searchWorker?.cancel()' in ref and 'searchWorker?.cancel()' in search
assert 'MemoWeaverDraftRecoveryStore.shared.write' in note
assert 'dataGeneration.uuidString' in main
assert 'undoUnlink()' in ref
assert 'replaceAllWithBrowserBackup' in db
assert 'case .backupTooLarge:' in db
assert 'WorkOSPDFJob' in (w/'WorkOSPreview.swift').read_text()
print('PASS QA v0.9.17 UI, shortcut, recovery, window, search cancellation, backup release source contracts')
PY
