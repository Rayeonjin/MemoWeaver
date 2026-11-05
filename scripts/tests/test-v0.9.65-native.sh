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
  -framework AppKit -framework SwiftUI -framework WebKit -framework PDFKit -framework UserNotifications \
  "${SOURCES[@]}" "$ROOT/Tests/UsabilityNativeSmoke.swift" -o "$TMP/native" > "$ROOT/build/Logs/native-0965-compiler.log" 2>&1
"$TMP/native"
