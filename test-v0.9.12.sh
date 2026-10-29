#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d /tmp/memoweaver-0912.XXXXXXXX)"
trap 'rm -rf -- "$TEMP"' EXIT
ARGS=(-swift-version 5 -Onone -j 1 -parse-as-library)
if [[ "$(uname -s)" == "Darwin" ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARGS+=(-sdk "$SDK" -target "$(uname -m)-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
fi
"$SWIFTC" "${ARGS[@]}" "$ROOT/WorkOSMac/EditorLineNumberRules.swift" \
    "$ROOT/WorkOSMac/SlashCommandCore.swift" "$ROOT/WorkOSMac/MemoryIdlePolicy.swift" \
    "$ROOT/Tests/IdlePerformanceSmoke.swift" -o "$TEMP/idle-performance"
"$TEMP/idle-performance"
python3 - "$ROOT" <<'PY_CHECK'
from pathlib import Path
import sys
r=Path(sys.argv[1]); mac=r/'WorkOSMac'
text=lambda name:(mac/name).read_text()
editor=text('MarkdownPlainEditor.swift'); idle=text('MemoryIdleModel.swift')
model=text('AppModel.swift'); ui=text('MainView.swift'); screen=text('MarkdownNoteScreen.swift')
assert 'MarkdownSlashPalette(query:' in editor and 'func handleSlashKey' in editor
assert 'if !hasMarkedText(), slashCoordinator' in editor
assert 'manager.invalidateDisplay(forCharacterRange:' in editor
assert 'if hasMarkedText() { syntaxRefreshAfterIME = true; return }' in editor
assert 'manager.glyphRange(forBoundingRect:' in editor
assert 'editorWasUsed()' in screen and 'Task.detached(priority: .utility)' in screen
assert 'func requestBackgroundIndex(noteID:' in idle and 'Task.sleep(nanoseconds: 3_000_000_000)' in idle
assert 'if isAutomaticMemoryIndexing { memoryIndexTask?.cancel() }' in idle
assert 'if isAutomaticRelationAnalysis { relationInferenceTask?.cancel() }' in idle
assert 'backgroundAIRevision == revision' in idle
assert 'MemoryIdlePolicy.defaultsKey' in ui and '수동 실행' in ui
assert 'sideNeighborsCache' in model and 'sideRangeCache' in model
assert 'memoryhome' in text('MemoryModel.swift') or 'sideRangeCache[noteID]' in text('MemoryModel.swift')
assert '<string>0.9.35</string>' in text('Info.plist') and '<string>68</string>' in text('Info.plist')
assert 'com.local.workos.notes' in text('Info.plist')
print('PASS v0.9.12 regression UI integration source hooks (no user DB touched)')
PY_CHECK
