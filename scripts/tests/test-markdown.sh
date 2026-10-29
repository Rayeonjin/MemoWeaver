#!/bin/bash
# Markdown experiment regression: temporary SQLite only; never opens user's DB.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
[[ "$(uname -s)" == Darwin ]] || { echo "Run on macOS with Apple Command Line Tools." >&2; exit 1; }
export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
SWIFTC="$(xcrun --sdk macosx --find swiftc)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
TEMP="$(mktemp -d /tmp/workos-markdown.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
CORE=("$ROOT/WorkOSMac/Models.swift" "$ROOT/WorkOSMac/WorkBlocks.swift"
      "$ROOT/WorkOSMac/MemoryCore.swift" "$ROOT/WorkOSMac/MemoryRelationCore.swift" "$ROOT/WorkOSMac/MemoryTimelineCore.swift" "$ROOT/WorkOSMac/VirtualMemoryCore.swift" "$ROOT/WorkOSMac/PlannerCore.swift"
      "$ROOT/WorkOSMac/QuickCaptureCore.swift" "$ROOT/WorkOSMac/Storage.swift" "$ROOT/WorkOSMac/MemoWeaverAttachments.swift"
      "$ROOT/WorkOSMac/ArchiveDecoder.swift" "$ROOT/WorkOSMac/SearchEngine.swift"
      "$ROOT/WorkOSMac/TemplateCore.swift" "$ROOT/WorkOSMac/NotesListFilter.swift"
      "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" "$ROOT/WorkOSMac/MarkdownCore.swift" "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" "$ROOT/WorkOSMac/NoteDocuments.swift"
      "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift")
echo "[MemoryHome] Markdown source/HTML/SQLite/backup smoke test"
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library \
    -sdk "$SDK" -target "${ARCH}-apple-macosx14.0" \
    "${CORE[@]}" "$ROOT/Tests/MarkdownExperimentSmoke.swift" -lsqlite3 \
    -o "$TEMP/markdown-test"
"$TEMP/markdown-test"
echo "[MemoryHome] Markdown entry points and stable legacy editor"
grep -Fq 'MarkdownNoteEditorScreen(' "$ROOT/WorkOSMac/MainView.swift"
if grep -Fq 'MD 메모' "$ROOT/WorkOSMac/MainView.swift"; then
    echo 'Retired duplicate MD note button remains' >&2; exit 1
fi
grep -Fq 'markdown: Bool = true' "$ROOT/WorkOSMac/AppModel.swift"
grep -Fq 'LegacyNoteTextConverter.editableText(for: note)' "$ROOT/WorkOSMac/MarkdownNoteScreen.swift"
grep -Fq 'WorkOSTextWrappingScrollView()' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'WorkOSLineNumberCanvas(editor: editor)' "$ROOT/WorkOSMac/MarkdownPlainEditor.swift"
grep -Fq 'bodyFormat' "$ROOT/WorkOSMac/Models.swift"
grep -Fq '0.9.15' "$ROOT/WorkOSMac/Info.plist"
echo "PASS unified Markdown source core. This is NOT a Mac GUI test; run ./build.sh next."
