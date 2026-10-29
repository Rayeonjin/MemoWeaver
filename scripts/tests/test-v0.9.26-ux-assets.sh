#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0926.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
ARGS=(-swift-version 5 -Onone -j 1 -parse-as-library)
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  ARGS+=(-sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macosx14.0")
else
  mkdir -p "$TMP/SQLite3"
  printf 'module SQLite3 [system] { header "/usr/include/sqlite3.h" link "sqlite3" export * }\n' > "$TMP/SQLite3/module.modulemap"
  ARGS+=(-I "$TMP")
fi
NAMES=(Models.swift QuickCaptureCore.swift WorkBlocks.swift MemoryCore.swift MemoryRelationCore.swift MemoryTimelineCore.swift ReferenceReaderCore.swift ReferencePanelCore.swift VirtualMemoryCore.swift PlannerCore.swift Storage.swift MemoWeaverAttachments.swift ArchiveDecoder.swift SearchEngine.swift TemplateCore.swift NotesListFilter.swift MarkdownSyntaxCore.swift MarkdownCore.swift OfficialDiagramRuntime.swift NoteDocuments.swift LegacyNoteTextConverter.swift OllamaService.swift)
SOURCES=()
for f in "${NAMES[@]}"; do SOURCES+=("$ROOT/WorkOSMac/$f"); done
"$SWIFTC" "${ARGS[@]}" "${SOURCES[@]}" "$ROOT/Tests/AttachmentsAndUXV0926Smoke.swift" -lsqlite3 -o "$TMP/ux-assets-test"
"$TMP/ux-assets-test"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY_CHECK'
from pathlib import Path
import plistlib,sys
r=Path(sys.argv[1]);w=r/'WorkOSMac'
a=(w/'AppModel.swift').read_text();m=(w/'MainView.swift').read_text();p=(w/'MarkdownPlainEditor.swift').read_text()
c=(w/'MemoWeaverEditorChrome.swift').read_text();doc=(w/'NoteDocuments.swift').read_text()
db=(w/'Storage.swift').read_text();app=(w/'WorkOSApp.swift').read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'],plist['CFBundleVersion'],plist['CFBundleIdentifier'])==('0.9.35','68','com.local.workos.notes')
assert 'onImagePaste:' in (w/'MarkdownNoteScreen.swift').read_text() and 'pastePNGIntoNote' in p
assert 'imageElementPattern' in (w/'MemoWeaverAttachments.swift').read_text()
assert 'resolvePreviewImages' in doc and 'exportMarkdownAssets' in (w/'WorkOSPreview.swift').read_text()
assert 'snapshotCompanion' in db and 'backupEntries' in db and 'validatedBackupEntries' in db
assert 'MemoWeaverTableSizeGrid' in c and 'tableGridPresented' in c
assert 'MermaidDiagramTemplates.Kind.allCases' in c and 'ganttParts' in (w/'MarkdownSyntaxCore.swift').read_text()
assert '@AppStorage("workos.appearance")' in c and 'EditorTypographyRules.zoom' in c
assert 'let previousNote = currentNote' in a and 'memoweaver.rightPane.visibility' in a
assert 'saveRightWidth: { preferredRightWidth = Double($0) }' in m and 'MemoWeaverPinnedSplitView(' in m
assert 'memoWeaverToggleFocusMode' in app and 'MemoWeaverQuickSearchPalette' in m
print('PASS v0.9.26 source contracts: image persistence, safe preview, toolbar, panel inheritance')
PY_CHECK
