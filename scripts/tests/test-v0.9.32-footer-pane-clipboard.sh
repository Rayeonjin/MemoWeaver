#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0932.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
swiftc -swift-version 5 -j 1 -parse-as-library \
    "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
    "$ROOT/Tests/PinnedPaneReopenV0932Smoke.swift" -o "$TMP/pane-layout"
"$TMP/pane-layout"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import plistlib,sys
r=Path(sys.argv[1]); w=r/'WorkOSMac';p=plistlib.loads((w/'Info.plist').read_bytes())
assert (p['CFBundleShortVersionString'],p['CFBundleVersion'],p['CFBundleIdentifier']) == ('0.9.35','68','com.local.workos.notes')
main=(w/'MainView.swift').read_text(); editor=(w/'MemoWeaverEditorChrome.swift').read_text()
split=(w/'MemoWeaverPinnedSplitView.swift').read_text();clip=(w/'MemoWeaverImageClipboard.swift').read_text()
shared=(w/'MemoWeaverPaneFooter.swift').read_text()
assert 'static let height: CGFloat = 30' in shared
assert 'MemoWeaverPaneFooterSurface()' in editor
assert 'MemoWeaverPaneFooter {' in main
assert 'listFooter' in main and 'auxiliaryFooter' in main
assert 'previewFooter' not in main
assert 'listQuery.trimmingCharacters' in main and 'displayedNotes.count' in main
assert 'state.captureVisibleWidthsBeforeTransition(in: split)' in split
assert 'state.cancelPendingDragAfterCapturing()' in split
assert 'lastExternalListWidth' in split and 'lastExternalRightWidth' in split
assert 'userWidthBeforeVisibilityChange(' in (w/'MemoWeaverPinnedPaneLayout.swift').read_text()
assert 'maximumClipboardRepresentationBytes = 96 * 1024 * 1024' in clip
assert 'frame(width: 33, height: 31)' not in editor.split('struct MemoWeaverEditorStatusBar:',1)[1]
assert 'Color.clear.frame(width: buttonWidth,' in editor and 'MemoWeaverThemePicker(selection: $appearance' in editor
assert 'MemoWeaverPasteSelection.containsActualTable(' in (w/'MarkdownPlainEditor.swift').read_text()
assert 'if let image = NSImage(pasteboard: board)' in clip
assert 'if let raw = board.data(forType: type), let png = normalizePNG(raw)' in clip
assert 'storePastedPNG' in (w/'AppModel.swift').read_text()
print('PASS footer common metrics, status content, pasteboard retry and transition snapshot source checks')
PY
if [[ "$(uname -s)" == Darwin ]]; then
    swiftc -swift-version 5 -j 1 -parse-as-library -framework AppKit -framework SwiftUI \
      "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
      "$ROOT/WorkOSMac/MemoWeaverPinnedSplitView.swift" \
      "$ROOT/Tests/PinnedPaneAppKitV0932Smoke.swift" -o "$TMP/appkit"
    "$TMP/appkit"
    swiftc -swift-version 5 -j 1 -parse-as-library -framework AppKit \
      "$ROOT/WorkOSMac/MemoWeaverAttachments.swift" \
      "$ROOT/WorkOSMac/MemoWeaverImageClipboard.swift" \
      "$ROOT/Tests/MemoWeaverPasteboardV0932Smoke.swift" -o "$TMP/pasteboard"
    "$TMP/pasteboard"
else
    printf 'SKIP macOS AppKit pane lifecycle and native clipboard test (macOS required).\n'
fi
