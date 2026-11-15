#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0965-native.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
SOURCES=()
for file in "$ROOT"/WorkOSMac/*.swift; do
  [[ "$file" == */WorkOSApp.swift ]] || SOURCES+=("$file")
done
swiftc -swift-version 5 -Onone -j 1 -parse-as-library -lsqlite3 \
  -framework AppKit -framework SwiftUI -framework WebKit -framework PDFKit -framework UserNotifications -framework JavaScriptCore \
  "${SOURCES[@]}" "$ROOT/Tests/UsabilityNativeSmoke.swift" "$ROOT/Tests/EditorImprovementsNativeChecks.swift" "$ROOT/Tests/EditorIMEPreview.swift" "$ROOT/Tests/BusinessMapNativeChecks.swift" "$ROOT/Tests/D3ForceNativeChecks.swift" "$ROOT/Tests/D3ForcePreview.swift" -o "$TMP/native" > "$ROOT/build/Logs/native-0965-compiler.log" 2>&1
if [[ "${MEMOWEAVER_KEEP_FORCE_QA_BINARY:-}" == 1 ]]; then
  mkdir -p "$ROOT/build/ForceQA"
  cp "$TMP/native" "$ROOT/build/ForceQA/native"
fi
"$TMP/native"
