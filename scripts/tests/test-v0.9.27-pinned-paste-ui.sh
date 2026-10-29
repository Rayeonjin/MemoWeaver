#!/bin/bash
# Portable policy checks + source contracts. Does not open user data or install.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0927.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -swift-version 5 -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
  "$ROOT/Tests/PinnedPanesV0927Smoke.swift" -o "$TMP/pinned"
"$TMP/pinned"
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY'
from pathlib import Path
import plistlib,sys
r=Path(sys.argv[1]);w=r/'WorkOSMac'
m=(w/'MainView.swift').read_text(); split=(w/'MemoWeaverPinnedSplitView.swift').read_text()
p=(w/'MarkdownPlainEditor.swift').read_text();i=(w/'MemoWeaverImageClipboard.swift').read_text();c=(w/'MemoWeaverEditorChrome.swift').read_text()
assert (plistlib.loads((w/'Info.plist').read_bytes())['CFBundleIdentifier']) == 'com.local.workos.notes'
assert 'MemoWeaverPinnedSplitView(' in m and 'listPreferred: CGFloat(preferredListWidth)' in m
assert 'rightPreferred: CGFloat(preferredRightWidth)' in m and 'right: activeRightPane.environmentObject(model)' in m
assert 'GeometryReader { split in' not in m and 'WorkspaceNativeWidthRecorder' not in m
assert 'resizeSubviewsWithOldSize' in split and 'NSSplitViewDelegate' in split
assert 'splitViewDidResizeSubviews' in split and 'NSEvent.pressedMouseButtons' in split
assert 'saveRightWidth?(width)' in split and 'saveListWidth?(width)' in split
assert 'MemoWeaverEditorImageInput.read(board)' in p and 'override func performDragOperation' in p
assert 'insertAttachment(png, at: sender.draggingLocation)' in p
assert 'pastePNGIntoNote = onImagePaste' in p and 'reportImageImportError' in p
assert 'NSPasteboard.PasteboardType("public.jpeg")' in i and 'fileURL(board)' in i
assert 'NSImage(pasteboard: board)' in i and '.mappedIfSafe' in i
assert '.menuStyle(.borderlessButton)' in c and '.menuIndicator(.hidden)' in c
assert 'frame(width: width, height: MemoWeaverPaneFooterMetrics.controlHeight)' in c and 'contentShape(Rectangle())' in c
print('PASS v0.9.27 source: native pinned split, attachment drag/paste, neutral menus, enlarged font targets')
PY
if [[ "$(uname -s)" == Darwin ]]; then
  swiftc -swift-version 5 -j 1 -parse-as-library -framework AppKit \
    "$ROOT/WorkOSMac/MemoWeaverAttachments.swift" \
    "$ROOT/WorkOSMac/MemoWeaverImageClipboard.swift" \
    "$ROOT/Tests/ImageClipboardMacV0927Smoke.swift" -o "$TMP/clipboard"
  "$TMP/clipboard"
else
  echo 'SKIP AppKit clipboard execution (requires macOS); source parse and policy tests completed.'
fi
