#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-force-qa.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
python3 "$ROOT/tools/verify-third-party-licenses.py"
swiftc -swift-version 5 -Onone -j 1 -parse-as-library -framework JavaScriptCore \
 "$ROOT/WorkOSMac/MemoryForceLayout.swift" "$ROOT/Tests/D3ForceLayoutSmoke.swift" -o "$TMP/force"
"$TMP/force"
