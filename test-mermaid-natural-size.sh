#!/bin/bash
# No native WebKit required; tests DOM sizing logic and source-only fallback.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
grep -Fq "width:\(width)px;height:\(height)px;max-width:none" "$ROOT/WorkOSMac/WorkBlocks.swift"
grep -Fq 'WorkOSOfficialDiagramRuntime.mermaidNaturalSizeScript' "$ROOT/WorkOSMac/NoteDocuments.swift"
grep -Fq '.workos-official-target.markmap-view svg{width:100%;height:100%;max-width:none}' "$ROOT/WorkOSMac/NoteDocuments.swift"
grep -Fq "flowchart: { htmlLabels: false, useMaxWidth: false }" "$ROOT/Vendor/official-diagrams/entry.js"
if command -v node >/dev/null 2>&1; then
  node "$ROOT/Tests/MermaidNaturalSizeSmoke.cjs"
  node "$ROOT/Tests/OfficialBridgeRuntimeMock.cjs"
else
  echo 'NOTICE Node unavailable: sizing JS runtime mock skipped (not needed in the installed app)'
fi
echo 'PASS fallback intrinsic Mermaid SVG, HTML preview and export shim, Markmap kept at full pane'
