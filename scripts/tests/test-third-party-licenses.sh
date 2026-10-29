#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
python3 "$ROOT/tools/verify-third-party-licenses.py"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-license-qa.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -swift-version 5 -Onone "$ROOT/WorkOSMac/OfficialDiagramRuntime.swift" \
  "$ROOT/Tests/ThirdPartyExportNoticesSmoke.swift" -o "$TMP/licenses"
"$TMP/licenses"
