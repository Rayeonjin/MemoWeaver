#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0915.XXXXXXXX")"
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
"$SWIFTC" "${ARGS[@]}" "${SOURCES[@]}" "$ROOT/Tests/ReferenceWorkspaceV0915Smoke.swift" -lsqlite3 -o "$TEMP/reference-test"
"$TEMP/reference-test"
"$SWIFTC" -frontend -parse "$ROOT/WorkOSMac/MainView.swift" "$ROOT/WorkOSMac/ReferenceWorkspacePane.swift" "$ROOT/WorkOSMac/MemoryModel.swift" >/dev/null
python3 - "$ROOT" <<'PY_CHECK'
import sys,pathlib
p=pathlib.Path(sys.argv[1]); w=p/'WorkOSMac'
s=(w/'MainView.swift').read_text(); r=(w/'ReferenceWorkspacePane.swift').read_text()
assert 'ReferenceWorkspacePane(currentNoteID: currentNoteID' in s
assert 'ReferenceNotePane(' not in s
assert 'WorkOSHTMLPreview(html: renderedHTML' in r
assert r.index('Label(renderedHTML == nil ? "미리보기"') < r.index('Label("복사"') < r.index('Label("별도 창"')
assert 'model.addConfirmedMemoryLink(sourceID, target)' in r
assert 'model.openReferenceEntity(entityID' in r
assert 'selectedNoteID =' not in r
assert 'private struct ManualMemoryLinkEditor: View' in r
assert 'Text(verbatim: relationDescription)' in r
assert 'Text(model.memoryTitle(sourceID) +' not in r
assert 'private struct ReferenceLinkedRows: View' in r
assert 'private struct ReferenceSearchRows: View' in r
assert 'private struct ReferenceRowActions {' in r
assert r'ForEach(entries, id: \.id)' in r
assert r'ForEach(results, id: \.id)' in r
assert 'ForEach(linked)' not in r
assert 'private var rowHeader: some View' in r
assert 'private var actionButtons: some View' in r
assert 'private var renderedOrRaw: some View' in r or '@ViewBuilder private var renderedOrRaw: some View' in r
assert '<string>0.9.35</string>' in (w/'Info.plist').read_text()
assert '<string>67</string>' in (w/'Info.plist').read_text()
print('PASS v0.9.15 sidebar UI, multi-expand, source/preview/copy/window, manual-link integration and version anchors (full GUI build on macOS only)')
PY_CHECK
