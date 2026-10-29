#!/bin/bash
# No actual private DB. The official JS requires a one-time networked build;
# default checks still verify wrapper safety and fallback without it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/memoryhome-official-smoke.XXXXXXXX")"
trap 'rm -rf -- "$TEMP"' EXIT
PLATFORM=()
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARCH="$(uname -m)"
  PLATFORM=(-sdk "$SDK" -target "${ARCH}-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
fi
"$SWIFTC" -swift-version 5 -Onone -j 1 -parse-as-library "${PLATFORM[@]}" \
  "$ROOT/WorkOSMac/Models.swift" \
  "$ROOT/WorkOSMac/QuickCaptureCore.swift" \
  "$ROOT/WorkOSMac/WorkBlocks.swift" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/WorkOSMac/MarkdownCore.swift" \
  "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" \
  "$ROOT/Tests/OfficialDiagramBridgeSmoke.swift" -o "$TEMP/official-smoke"
"$TEMP/official-smoke"
if command -v node >/dev/null 2>&1; then
  node "$ROOT/Tests/OfficialBridgeRuntimeMock.cjs"
fi
node --check "$ROOT/Vendor/official-diagrams/entry.js" 2>/dev/null || {
  # Node is not an app build dependency: parse with node only when installed.
  if command -v node >/dev/null 2>&1; then echo 'FAIL: bridge JS invalid' >&2; exit 1; fi
  echo '[MemoryHome] Node absent; JavaScript syntax check skipped (optional developer prep).'
}
grep -Fq 'WKUserScript(' "$ROOT/WorkOSMac/WorkOSPreview.swift"
grep -Fq 'embedForStandaloneExport' "$ROOT/WorkOSMac/NoteDocuments.swift"
grep -Fq 'callAsyncJavaScript(waitScript' "$ROOT/WorkOSMac/WorkOSPreview.swift"
grep -Fq "connect-src 'none'" "$ROOT/WorkOSMac/NoteDocuments.swift"
if [[ -s "$ROOT/WorkOSMac/Resources/official-diagrams.js" ]]; then
  grep -Fq 'MemoryHomeOfficialDiagrams' "$ROOT/WorkOSMac/Resources/official-diagrams.js" || { echo 'FAIL: prepared JS is incomplete' >&2; exit 1; }
  if command -v node >/dev/null 2>&1; then node --check "$ROOT/WorkOSMac/Resources/official-diagrams.js"; fi
  echo 'PASS official JS is present and will be included in the app (verify macOS GUI after build).'
else
  if [[ "${1:-}" == --require-bundle ]]; then
    echo 'FAIL: official JS not prepared. Run ./scripts/renderers/prepare-official-renderers.sh once on a networked Mac with Node 22+.' >&2
    exit 1
  fi
  echo 'NOTICE: official JS absent; offline SVG fallback works. Optional: ./scripts/renderers/prepare-official-renderers.sh'
fi
