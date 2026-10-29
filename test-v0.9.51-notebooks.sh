#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
cd "$ROOT"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-notebook-qa.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
SQL_FLAGS=()
if [[ "$(uname -s)" != Darwin ]]; then
  mkdir -p "$TMP/Modules/SQLite3"
  printf 'module SQLite3 [system] { header "/usr/include/sqlite3.h" link "sqlite3" export * }\n' > "$TMP/Modules/SQLite3/module.modulemap"
  SQL_FLAGS=(-I "$TMP/Modules")
fi
"$SWIFTC" -frontend -parse WorkOSMac/*.swift
"$SWIFTC" WorkOSMac/NotebookMembershipCore.swift Tests/MultiNotebookSmoke.swift -o "$TMP/notebook-core"
"$SWIFTC" WorkOSMac/NoteDraftRecovery.swift Tests/MultiNotebookRecoveryFixSmoke.swift -o "$TMP/notebook-recovery"
"$TMP/notebook-recovery"
"$TMP/notebook-core"
"$SWIFTC" WorkOSMac/NoteDraftRecovery.swift Tests/MultiNotebookRecoveryFixSmoke.swift -o "$TMP/notebook-recovery"
"$TMP/notebook-recovery"
python3 - "$ROOT" <<'PY'
import pathlib,sys
root=pathlib.Path(sys.argv[1]);s=(root/'WorkOSMac/Storage.swift').read_text()
assert 'CREATE TABLE IF NOT EXISTS note_notebooks' in s
assert 'note_notebooks_migrated_v1' in s
assert 'snapshotBackupIfNeeded(force: true)' in s
assert '"notebookIds"' in s
assert 'if affected > 0' in s
assert 'notebookIDs: notebookIDs' in (root/'WorkOSMac/MarkdownNoteScreen.swift').read_text()
assert 'note.notebookIDs.contains(bookID)' in (root/'WorkOSMac/NotesListFilter.swift').read_text()
assert 'MemoWeaverQuickTipButton' in (root/'WorkOSMac/MemoWeaverNativeWindowChrome.swift').read_text()
assert 'MemoWeaverDividerOverlay' in (root/'WorkOSMac/MemoWeaverNativeWindowChrome.swift').read_text()
assert '"마인드맵"' in (root/'WorkOSMac/MarkdownCore.swift').read_text()
assert 'textformat.superscript' in (root/'WorkOSMac/MarkdownNoteScreen.swift').read_text()
print('PASS source-contract guards')
PY
# Compile and EXECUTE the actual LocalDatabase and JSON-export/import code.
S=(Models.swift Storage.swift NotebookMembershipCore.swift NotesListFilter.swift WorkBlocks.swift QuickCaptureCore.swift MemoryCore.swift MemoryRelationCore.swift VirtualMemoryCore.swift MemoWeaverAttachments.swift PlannerCore.swift LegacyNoteTextConverter.swift MemoryTimelineCore.swift)
FILES=()
for file in "${S[@]}"; do FILES+=("$ROOT/WorkOSMac/$file"); done
"$SWIFTC" ${SQL_FLAGS[@]+"${SQL_FLAGS[@]}"} -Onone -j 1 -lsqlite3 "${FILES[@]}" "$ROOT/Tests/MultiNotebookIntegration.swift" -o "$TMP/notebook-db"
python3 "$ROOT/Tests/LegacyNotebookFixture.py" "$TMP/legacy"
"$TMP/notebook-db" "$TMP/legacy" "$TMP/restored"
