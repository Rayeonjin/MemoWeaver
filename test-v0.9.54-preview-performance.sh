#!/bin/bash
# Live-preview latency, bounded work, and safety source contract (v0.9.54).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-v54-preview.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
"$SWIFTC" -frontend -parse "$ROOT"/WorkOSMac/*.swift
"$SWIFTC" -swift-version 5 -Onone \
  "$ROOT/WorkOSMac/MemoWeaverPreviewPipeline.swift" \
  "$ROOT/Tests/PreviewPipelineV0954Smoke.swift" -o "$TMP/preview-policy-smoke"
"$TMP/preview-policy-smoke"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
editor=(root/'WorkOSMac/MarkdownNoteScreen.swift').read_text()
web=(root/'WorkOSMac/WorkOSPreview.swift').read_text()
engine=(root/'WorkOSMac/MemoWeaverPreviewPipeline.swift').read_text()
previous=(root/'WorkOSMac/MemoWeaverPassiveTooltip.swift').read_text()
assert 'Task.sleep(nanoseconds: 550_000_000)' not in editor
assert 'pendingPreviewFirstChangeAt' in editor
assert 'schedulePreview(immediate: true)' in editor
assert 'previewRevision += 1 // invalidate already-running conversion' in editor
assert 'MemoWeaverPreviewRenderer.shared.render' in editor
assert 'let render = Task.detached' not in editor[editor.index('private func schedulePreview('):]
assert 'if previewHTML != html { previewHTML = html }' in editor
assert 'func enqueue(_ html: String' in web and 'private var queuedHTML' in web
assert 'guard finishLoad(in: webView, succeeded: true) else { return }' in web
assert 'didFailProvisionalNavigation' in web and 'didFail navigation:' in web
assert 'needsOfficialDiagramEngine(html)' in web and 'controller.removeAllUserScripts()' in web
assert 'let officialJS = WorkOSOfficialDiagramRuntime.source' not in web
assert 'guard !Task.isCancelled else { return nil }' in engine
assert 'panel.ignoresMouseEvents = true' in previous
assert (root/'WorkOSMac/Info.plist').read_text().count('<string>0.9.54</string>') == 1
assert '<string>87</string>' in (root/'WorkOSMac/Info.plist').read_text()
assert 'CACHE_ORIGIN' in (root/'build.sh').read_text()
print('PASS v0.9.54: latest-only HTML navigation, no stale preview commit,')
print('  cancelled preview guard, lazy JS bridge, retained click-through tips')
PY
