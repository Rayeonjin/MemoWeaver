#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0933.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
swiftc -swift-version 5 -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/PasteTableCore.swift" \
  "$ROOT/WorkOSMac/MemoWeaverPasteSelection.swift" \
  "$ROOT/Tests/PasteSelectionV0933Smoke.swift" -o "$TMP/routing"
"$TMP/routing"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys,plistlib,hashlib
r=Path(sys.argv[1]); w=r/'WorkOSMac'
p=plistlib.loads((w/'Info.plist').read_bytes())
assert (p['CFBundleShortVersionString'],p['CFBundleVersion'],p['CFBundleIdentifier'])==('0.9.35','68','com.local.workos.notes')
bar=(w/'MemoWeaverPaneFooter.swift').read_text()
assert 'static let height: CGFloat = 30' in bar
assert 'static let controlHeight: CGFloat = 26' in bar
assert 'strokeBorder(' not in bar and 'Color.clear' in bar
assert 'Color.primary.opacity(0.10)' in bar
chrome=(w/'MemoWeaverEditorChrome.swift').read_text()
assert 'MemoWeaverPaneFooterSurface()' in chrome
assert chrome.count('MemoWeaverFooterControl()') >= 2 and 'MemoWeaverThemePicker(selection: $appearance' in chrome
assert 'MemoWeaverPaneFooterMetrics.controlHeight' in chrome
main=(w/'MainView.swift').read_text()
assert 'MemoWeaverPaneFooter {' in main and 'listFooter' in main and 'auxiliaryFooter' in main
assert 'MemoWeaverThemePicker(selection: $previewAppearance' in main
editor=(w/'MarkdownPlainEditor.swift').read_text()
assert 'override func paste(_ sender: Any?)' in editor
assert 'MemoWeaverPasteSelection.containsActualTable(' in editor
assert '@objc func pasteClipboardImage(_ sender: Any?)' in editor
assert 'override var readablePasteboardTypes:' in editor
assert 'override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool' in editor
assert 'MemoWeaverEditorImageInput.containsImage(NSPasteboard.general)' in editor
assert 'case .png(let png)' in editor and 'insertAttachment(png, at: nil)' in editor
assert 'reportImageImportError?' in editor
app=(w/'WorkOSApp.swift').read_text()
assert 'NSApp.sendAction(#selector(WorkOSMarkdownTextView.pasteClipboardImage(_:))' in app
assert '.keyboardShortcut("v", modifiers: [.command, .option])' in app
clip=(w/'MemoWeaverImageClipboard.swift').read_text()
assert 'board.pasteboardItems ?? []' in clip and 'typeSummary' in clip
# Immutable data, renderer, split and attachment-storage files compared to
# the known v0.9.32 handoff version: no schema or pane regression by this patch.
expected={
 'Storage.swift':'f3bf7023f044f0c92792b2ddd91bfaefa738e79dcf6cb6ceb8ea4602bef92199',
 'MemoWeaverAttachments.swift':'bbcbb8553c40ec3072917b26932bd97aaf8e4db4f06e0cc394c26d085a1cc9db',
 'MemoWeaverPinnedSplitView.swift':'972e15b504a7ef371a22c8fa5b75d64bf2b1759c404dd7a40f8850c1b6f5302d',
 'MemoWeaverPinnedPaneLayout.swift':'2ca5cf6123c7eff0f41458cc2b97e0c398f691d382188dda1a1f09be333a3278',
}
for name, sha in expected.items():
    assert hashlib.sha256((w/name).read_bytes()).hexdigest()==sha, f'Unexpected mutation: {name}'
print('PASS v0.9.33 flat footers, paste route, menu fallback, data/split preservation')
PY
if [[ "$(uname -s)" == Darwin ]]; then
  swiftc -swift-version 5 -j 1 -parse-as-library -framework AppKit \
    "$ROOT/WorkOSMac/MemoWeaverAttachments.swift" \
    "$ROOT/WorkOSMac/MemoWeaverImageClipboard.swift" \
    "$ROOT/WorkOSMac/PasteTableCore.swift" \
    "$ROOT/WorkOSMac/MemoWeaverPasteSelection.swift" \
    "$ROOT/Tests/ClipboardFormatsV0933Smoke.swift" -o "$TMP/clipboard"
  "$TMP/clipboard"
else
  echo 'SKIP macOS native pasteboard smoke (macOS required).'
fi
