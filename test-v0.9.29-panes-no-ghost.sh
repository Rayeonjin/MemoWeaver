#!/bin/bash
# v0.9.29: no ghost dividers; no accidental outer width changes; no editor remount.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0929.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -swift-version 5 -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
  "$ROOT/Tests/PinnedPaneVisibilityV0929Smoke.swift" -o "$TMP/visibility"
"$TMP/visibility"
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY'
from pathlib import Path
import plistlib, sys
r=Path(sys.argv[1]);w=r/'WorkOSMac'
split=(w/'MemoWeaverPinnedSplitView.swift').read_text()
model=(w/'MemoWeaverPinnedPaneLayout.swift').read_text()
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert (plist['CFBundleShortVersionString'], plist['CFBundleVersion'])==('0.9.35','68')
assert plist['CFBundleIdentifier']=='com.local.workos.notes'
assert 'split.arrangesAllSubviews = false' in split
assert 'state.reconcileArrangedPanes(in: split)' in split
assert 'split.arrangedSubviews' in split and 'splitView.arrangedSubviews' in split
assert 'pane.removeFromSuperview()' in split
assert 'split.insertArrangedSubview(pane, at: index)' in split
assert 'let activeDividerCount = max(0, splitView.arrangedSubviews.count - 1)' in split
assert 'split.needsDisplay = true' in split
assert 'shouldHideDividerAt' not in split
assert 'left.isHidden' not in split and 'auxiliary.isHidden' not in split
assert 'view.layer?.masksToBounds = true' in split
assert 'visiblePaneOrder' in model and '.editor' in model
assert 'splitViewDidResizeSubviews' in split and 'saveRightWidth?(width)' in split
assert 'saveListWidth?(width)' in split
print('PASS v0.9.29 source: only visible panes arranged, true structural removal, explicit divider invalidation')
PY
if [[ "$(uname -s)" == Darwin ]]; then
  # This catches real AppKit interface/ordering errors the Linux source parser cannot.
  swiftc -swift-version 5 -j 1 -parse-as-library -framework AppKit -framework SwiftUI \
    "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
    "$ROOT/WorkOSMac/MemoWeaverPinnedSplitView.swift" \
    "$ROOT/Tests/PinnedPaneAppKitV0929Smoke.swift" -o "$TMP/native-appkit"
  "$TMP/native-appkit"
else
  printf 'SKIP native AppKit subview lifecycle: requires macOS; pure Swift/source checks passed.\n'
fi
