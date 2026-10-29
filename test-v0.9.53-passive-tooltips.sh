#!/bin/bash
# v0.9.53: click-through tooltip contract and retained editor regressions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-v53-qa.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
"$SWIFTC" -frontend -parse "$ROOT"/WorkOSMac/*.swift
if [[ "$(uname -s)" == Darwin ]]; then
    # First catch AppKit/SwiftUI type errors in the new tooltip layer alone.
    "$SWIFTC" -swift-version 5 -typecheck \
        "$ROOT/WorkOSMac/MemoWeaverPassiveTooltip.swift" \
        "$ROOT/WorkOSMac/MemoWeaverTooltips.swift"
fi
"$SWIFTC" -typecheck "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift"
"$SWIFTC" -Onone "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
    "$ROOT/Tests/ContextTooltipSymbolsV0952Smoke.swift" -o "$TMP/context-smoke"
"$TMP/context-smoke"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); src = p/'WorkOSMac'
sw = (src/'MemoWeaverTooltips.swift').read_text()
center = (src/'MemoWeaverPassiveTooltip.swift').read_text()
native = (src/'MemoWeaverNativeWindowChrome.swift').read_text()
main = (src/'MainView.swift').read_text()
assert 'MemoWeaverPassiveTooltipCenter.shared.schedule' in sw
assert '.background(MemoWeaverPassiveTooltipAnchor(box: anchorBox))' in sw
assert '.popover(' not in sw, 'tooltip cannot use an interactive popover'
assert '@AppStorage("memoweaver.ui.tooltipsEnabled")' in sw
assert 'panel.ignoresMouseEvents = true' in center
assert 'override var canBecomeKey: Bool { false }' in center
assert 'override func hitTest(_ point: NSPoint) -> NSView? { nil }' in center
assert 'return event' in center, 'monitor must return the original click unchanged'
assert 'Self.hoverDelay' in center and 'hoverDelay: TimeInterval = 0.13' in center
assert 'MemoWeaverPassiveTooltipCenter.shared.hide(for: self)' in native
assert 'super.mouseDown(with: event)' in native
quick = native[native.index('private final class MemoWeaverQuickTipButton'):native.index('// Unlike v0.9.42')]
assert 'NSPopover' not in quick, 'toolbar hint must not spawn a popover'
assert 'hintPopover' not in quick
assert '.memoTooltip(title)' in main
assert 'hoveredRailPage' not in main, 'duplicate rail tooltip removed'
assert '<string>0.9.53</string>' in (src/'Info.plist').read_text()
assert '<string>86</string>' in (src/'Info.plist').read_text()
assert 'MemoWeaverDividerSeamOverlay' in native
assert 'NSTrackingSeparatorToolbarItem(' not in native
assert 'coordinator.forceRefreshContext(in: editor)' in (src/'MarkdownPlainEditor.swift').read_text()
print('PASS v0.9.53: click-through passive panel, unmodified click event,')
print('  130ms hints, user preference, native/SwiftUI coverage, core regressions')
PY
