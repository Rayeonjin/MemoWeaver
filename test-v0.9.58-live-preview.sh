#!/bin/bash
# Offline safety/behavior QA for immediate template events and WebKit shell reuse.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-v57-preview.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SWIFTC="$(command -v swiftc)"
"$SWIFTC" -frontend -parse "$ROOT"/WorkOSMac/*.swift
"$SWIFTC" -swift-version 5 -Onone \
  "$ROOT/WorkOSMac/MemoWeaverPreviewPipeline.swift" \
  "$ROOT/WorkOSMac/MemoWeaverLivePreviewUpdateCore.swift" \
  "$ROOT/Tests/PreviewPipelineV0954Smoke.swift" \
  -o "$TMP/preview-policy"
"$TMP/preview-policy"
"$SWIFTC" -swift-version 5 -Onone \
  "$ROOT/WorkOSMac/MemoWeaverPreviewPipeline.swift" \
  "$ROOT/WorkOSMac/MemoWeaverLivePreviewUpdateCore.swift" \
  "$ROOT/Tests/PreviewLiveV0955Smoke.swift" \
  "$ROOT/Tests/PreviewPolicyV0955FakeDocs.swift" \
  -o "$TMP/preview-live"
"$TMP/preview-live"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
r=Path(sys.argv[1]); w=r/'WorkOSMac'
editor=(w/'MarkdownPlainEditor.swift').read_text()
view=(w/'MarkdownNoteScreen.swift').read_text()
web=(w/'WorkOSPreview.swift').read_text()
assert 'publishEditedTextIfNeeded(in: editor)' in editor
assert 'lastPublishedText = source' in editor
assert 'onTemplateInsertion()' in editor
assert 'forceRefreshContext(in: editor)' in editor
assert 'schedulePreview(immediate: true)' in view
assert 'onTemplateInsertion: {' in view
assert 'view.callAsyncJavaScript(Self.patchScript' in web
assert 'newNode.replaceWith(oldNode)' in web
assert 'window.__MWDiagramRefreshRunning' in web
assert 'webViewWebContentProcessDidTerminate' in web
assert 'document.title = nextHeading.textContent' in web
assert 'guard !Task.isCancelled, token == previewRevision' in view
assert 'panel.ignoresMouseEvents = true' in (w/'MemoWeaverPassiveTooltip.swift').read_text()
assert '.memoTooltip(title, when: compact)' in (w/'MainView.swift').read_text()
assert 'when: notebookIDs.count > 1' in (w/'MemoWeaverEditorChrome.swift').read_text()
assert '<string>0.9.58</string>' in (w/'Info.plist').read_text()
assert '<string>91</string>' in (w/'Info.plist').read_text()
print('PASS v0.9.58: template edits explicitly publish once; engine stays alive,')
print('  tooltip removal/conditional policy and offline/no-click-blocking intact')
PY
if command -v node >/dev/null 2>&1; then
  python3 - "$ROOT" "$TMP/patch.js" <<'PY'
from pathlib import Path
import sys
s=(Path(sys.argv[1])/'WorkOSMac/WorkOSPreview.swift').read_text()
script=s.split('private static let patchScript = #"""',1)[1].split('"""#',1)[0]
Path(sys.argv[2]).write_text('async function update(fragment) {\n'+script+'\n}\n')
PY
  node --check "$TMP/patch.js"
  echo 'PASS v0.9.58: incremental WKWebView JavaScript syntax'
fi
