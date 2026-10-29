#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0924-legacy.XXXXXXXX")"
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
  "$ROOT/Tests/LegacyChartV0924Smoke.swift" -o "$TMP/legacy-chart"
"$TMP/legacy-chart"
"$SWIFTC" -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY_ASSERT'
from pathlib import Path
import sys, plistlib
r = Path(sys.argv[1]); w = r / 'WorkOSMac'
core = (w/'MarkdownCore.swift').read_text()
slash = (w/'SlashCommandCore.swift').read_text()
chrome = (w/'MemoWeaverEditorChrome.swift').read_text()
plist = plistlib.loads((w/'Info.plist').read_bytes())
assert plist['CFBundleShortVersionString']=='0.9.35' and plist['CFBundleVersion']=='68'
assert plist['CFBundleIdentifier']=='com.local.workos.notes'
assert 'renderLegacyVegaBars(code)' in core and 'source.utf8.count <= 64_000' in core
assert '```vega-lite' not in slash
assert 'MermaidChartTemplates.Kind.allCases' in chrome
assert not (w/'Resources/vega.js').exists() and not (w/'Resources/vega-lite.js').exists()
assert not (w/'Resources/vega-embed.js').exists() and not (w/'Resources/chart.js').exists()
print('PASS v0.9.25 source contracts: no Vega authoring/runtime, bounded legacy renderer, unchanged app identity')
PY_ASSERT
