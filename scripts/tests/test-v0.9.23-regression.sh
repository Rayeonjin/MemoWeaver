#!/bin/bash
# v0.9.23 offline-only guardrails. No clipboard or user database is opened.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0923.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
ARGS=(-swift-version 5 -Onone -j 1)
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  ARGS+=(-sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macosx14.0")
fi
"$SWIFTC" "${ARGS[@]}" "$ROOT/WorkOSMac/MarkdownTableTextCore.swift" \
  "$ROOT/Tests/MarkdownTableTextSmoke.swift" -o "$TMP/table"
"$TMP/table"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY_ASSERT'
import sys, plistlib
from pathlib import Path
r=Path(sys.argv[1]);w=r/'WorkOSMac'
m=(w/'MainView.swift').read_text(); e=(w/'MarkdownPlainEditor.swift').read_text()
a=(w/'WorkOSApp.swift').read_text(); p=(w/'MemoWeaverQuickSearchPalette.swift').read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert plist['CFBundleShortVersionString']=='0.9.35' and plist['CFBundleVersion']=='68'
assert plist['CFBundleIdentifier']=='com.local.workos.notes'
assert '.onHover { hovered in' in m and 'Text(title)' in m and '.allowsHitTesting(false)' in m
assert 'if page == .search {' in m and 'showQuickSearch = true' in m
assert 'Notification.Name("MemoWeaverOpenQuickSearch")' in m
assert 'Notification.Name("MemoWeaverToggleFocusMode")' in m
assert 'MemoWeaverLayoutSwitchSafety.prepare()' in m and 'focusModeEnabled.toggle()' in m
assert 'effectiveListVisible' in m and 'effectiveRightPaneVisible' in m
assert 'noteListVisible.toggle()' in m and 'MemoWeaverPinnedSplitView(' in m
assert 'DragGesture(minimumDistance:' not in m
assert 'MarkdownTableTextCore.conversion(in: string, selection: selectedRange())' in e
assert 'insertText(result.tsv, replacementRange: result.range)' in e
assert 'copyMarkdownTableAsTSV' in e and 'override func paste(_ sender' in e
assert 'NSEvent.pressedMouseButtons == 0' in e and 'ensureLayout(forCharacterRange:' in e
assert 'manager.ensureLayout(for: container)' not in e.split('private func caretVisualLineRect()',1)[1].split('    func caretDidMove()',1)[0]
assert '.keyboardShortcut("k", modifiers: .command)' in a
assert '.keyboardShortcut("f", modifiers: [.command, .option])' in a
assert 'model.openNote(note.id)' in p and '.allSearch: model.selectedPage = .search' in p
assert 'WorkOSSearch.find' not in p and 'Ollama' not in p
print('PASS v0.9.23 source contracts: safe table conversion, native split, hover names, quick search, reversible focus, bounded layout work')
PY_ASSERT
