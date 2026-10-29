#!/bin/bash
# MemoWeaver 0.9.52: fast content-sized tooltips, immediate math context,
# full math symbol catalog and native divider seam source regression.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-v52-qa.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
"$SWIFTC" -frontend -parse "$ROOT"/WorkOSMac/*.swift
"$SWIFTC" -typecheck "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift"
"$SWIFTC" -Onone "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
    "$ROOT/Tests/ContextTooltipSymbolsV0952Smoke.swift" \
    -o "$TMP/context-tooltip-math"
"$TMP/context-tooltip-math"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1]); src=r/'WorkOSMac'
tip=(src/'MemoWeaverTooltips.swift').read_text()
assert 'MemoWeaverTooltipLayout.size(for: message)' in tip
assert '.frame(width: size.width, height: size.height' in tip
assert '130_000_000' in tip  # preserve the accepted 0.13s delay
assert '@AppStorage("memoweaver.ui.tooltipsEnabled")' in tip
native=(src/'MemoWeaverNativeWindowChrome.swift').read_text()
assert 'MemoWeaverDividerSeamOverlay' in native
assert 'gap <= 18' in native
assert 'ensureDividerSeamOverlay(in: window)' in native
assert 'NSSplitView' in native and 'NSTrackingSeparatorToolbarItem(' not in native
editor=(src/'MarkdownPlainEditor.swift').read_text()
assert 'coordinator.forceRefreshContext(in: editor)' in editor
assert 'cachedLineStarts.count != previousLineCount' in editor
palette=(src/'MarkdownNoteScreen.swift').read_text()
for title in ('그리스 소문자','그리스 대문자','비교·관계','집합·수 체계',
              '논리','연산·미적분','화살표'):
    assert 'Menu("'+title+'")' in palette, title
plist=(src/'Info.plist').read_text()
assert '<string>0.9.52</string>' in plist
assert '<string>85</string>' in plist
print('PASS 0.9.52: responsive tooltip sizing, 130ms speed, seam bridge,\n'
      '  freshly inserted block context, 7 math-menu categories and version')
PY
