#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0923-mermaid.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
ARGS=(-swift-version 5 -Onone -j 1 -parse-as-library)
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  ARGS+=(-sdk "$(xcrun --sdk macosx --show-sdk-path)" -target "$(uname -m)-apple-macosx14.0")
fi
"$SWIFTC" "${ARGS[@]}" \
  "$ROOT/WorkOSMac/Models.swift" \
  "$ROOT/WorkOSMac/QuickCaptureCore.swift" \
  "$ROOT/WorkOSMac/WorkBlocks.swift" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/WorkOSMac/MarkdownCore.swift" \
  "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" \
  "$ROOT/Tests/MermaidChartV0923Smoke.swift" -o "$TMP/mermaid-charts"
"$TMP/mermaid-charts"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY_ASSERT'
from pathlib import Path
import plistlib,sys
r=Path(sys.argv[1]);w=r/'WorkOSMac'
main=(w/'MainView.swift').read_text();chrome=(w/'MemoWeaverEditorChrome.swift').read_text()
screen=(w/'MarkdownNoteScreen.swift').read_text();bridge=(w/'OfficialDiagramRuntime.swift').read_text()
core=(w/'MarkdownCore.swift').read_text();slash=(w/'SlashCommandCore.swift').read_text()
p=plistlib.loads((w/'Info.plist').read_bytes())
assert p['CFBundleIdentifier']=='com.local.workos.notes'
assert p['CFBundleShortVersionString']=='0.9.35' and p['CFBundleVersion']=='68'
assert 'auxiliaryFooter' in main and 'MemoWeaverPaneFooter {' in main
assert 'static let height: CGFloat = 30' in (w/'MemoWeaverPaneFooter.swift').read_text()
assert 'Menu {\n                        Button("시스템 테마"' not in main
assert 'followPreviewCaret.toggle()' in main and '@AppStorage("memoweaver.preview.appearance")' in main
assert 'MemoWeaverThemePicker(selection: $previewAppearance, scope: "미리보기")' in main
assert 'chartChoices' in chrome and 'MermaidChartTemplates.Kind.allCases' in chrome
assert 'MemoWeaverInsertToolbar { kind in' in screen and 'onInsertChart: { chart in' in screen
assert 'case .mermaidXY: return [[.chartAxes, .chartPlots]]' in screen
assert 'case .mermaidPie: return [[.chartPie]]' in screen
assert 'data-workos-chart=' in bridge and "svg.style.setProperty('max-width', '100%', 'important')" in bridge
assert 'private static func renderLegacyVegaBars' in core and '64_000' in core
assert 'case "vega-lite", "vegalite":' in core and 'renderLegacyVegaBars(code)' in core
assert '```vega-lite' not in slash and 'xychart-beta' in slash
print('PASS v0.9.23 source contracts: bottom controls, four charts, safe legacy source, responsive SVG')
PY_ASSERT
