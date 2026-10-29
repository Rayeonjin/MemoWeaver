#!/bin/bash
# macOS diagnostic for actual local Ollama models using SYNTHETIC text only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
[[ "$(uname -s)" == Darwin ]] || { echo "Run on your Mac with Ollama running." >&2; exit 1; }
export DEVELOPER_DIR="${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}"
SWIFTC="$(xcrun --sdk macosx --find swiftc)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
TMP="$(mktemp -d /tmp/workos-ai-smoke.XXXXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT
"$SWIFTC" -swift-version 5 -Onone -sdk "$SDK" -target "$(uname -m)-apple-macosx14.0" \
  "$ROOT/WorkOSMac/Models.swift" "$ROOT/WorkOSMac/WorkBlocks.swift" \
  "$ROOT/WorkOSMac/QuickCaptureCore.swift" "$ROOT/WorkOSMac/Storage.swift" "$ROOT/WorkOSMac/MemoWeaverAttachments.swift" \
  "$ROOT/WorkOSMac/PlannerCore.swift" "$ROOT/WorkOSMac/MemoryCore.swift" "$ROOT/WorkOSMac/MemoryRelationCore.swift" "$ROOT/WorkOSMac/MemoryTimelineCore.swift" "$ROOT/WorkOSMac/VirtualMemoryCore.swift" \
  "$ROOT/WorkOSMac/SearchEngine.swift" "$ROOT/WorkOSMac/OllamaService.swift" "$ROOT/WorkOSMac/LegacyNoteTextConverter.swift" \
  "$ROOT/Tests/AISmoke.swift" -lsqlite3 -o "$TMP/AISmoke"
"$TMP/AISmoke" "$@"
