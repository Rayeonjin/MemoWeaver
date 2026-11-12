#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
source "$ROOT/tools/qa-swift-env.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-update-qa.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -swift-version 5 -Onone -j 1 -parse-as-library \
 "$ROOT/WorkOSMac/BuildInfo.swift" "$ROOT/WorkOSMac/MemoWeaverUpdateCheck.swift" \
 "$ROOT/WorkOSMac/MemoWeaverUpdateCheckView.swift" "$ROOT/Tests/UpdateCheckSmoke.swift" -o "$TMP/update-check"
"$TMP/update-check"
