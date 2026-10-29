#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-slash-0913.XXXXXXXX")"
trap 'rm -rf -- "$TEMP"' EXIT
ARGS=(-swift-version 5 -Onone -j 1 -parse-as-library)
if [[ "$(uname -s)" == "Darwin" ]]; then
  export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
  SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  SDK="$(xcrun --sdk macosx --show-sdk-path)"
  ARGS+=(-sdk "$SDK" -target "$(uname -m)-apple-macosx14.0")
else
  SWIFTC="$(command -v swiftc)"
fi
"$SWIFTC" "${ARGS[@]}" \
  "$ROOT/WorkOSMac/MarkdownSyntaxCore.swift" \
  "$ROOT/WorkOSMac/SlashCommandCore.swift" \
  "$ROOT/WorkOSMac/MarkdownSlashContextCore.swift" \
  "$ROOT/Tests/SlashContextSmoke.swift" -o "$TEMP/slash-test"
"$TEMP/slash-test"
# Linux parser can inspect SwiftUI/AppKit declarations, but cannot typecheck
# them without macOS SDK. The full Mac build remains an installation check.
"$SWIFTC" -frontend -parse "$ROOT/WorkOSMac/MarkdownSlashPalette.swift" \
  "$ROOT/WorkOSMac/MarkdownPlainEditor.swift" >/dev/null
python3 - "$ROOT" <<'PY_CHECK'
from pathlib import Path
import sys
root = Path(sys.argv[1]); mac = root/'WorkOSMac'
editor = (mac/'MarkdownPlainEditor.swift').read_text()
palette = (mac/'MarkdownSlashPalette.swift').read_text()
assert 'MarkdownSlashContextCore.trigger(' in editor
assert 'MarkdownSlashContextCore.matches(' in editor
assert 'if !hasMarkedText(), slashCoordinator?.handleSlashKey' in editor
assert 'editor.insertText(prepared.source, replacementRange: trigger.range)' in editor
assert 'source.substring(with: trigger.range) == "/" + trigger.query' in editor
assert 'ScrollViewReader' in palette and 'reader.scrollTo(index' in palette
assert 'min(CGFloat(items.count) * 49, 330)' in palette
assert '<string>0.9.35</string>' in (mac/'Info.plist').read_text()
assert '<string>67</string>' in (mac/'Info.plist').read_text()
print('PASS v0.9.14 slash palette integration anchors and version')
PY_CHECK
