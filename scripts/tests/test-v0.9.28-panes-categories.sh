#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-0928.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
swiftc -swift-version 5 -j 1 -parse-as-library \
  "$ROOT/WorkOSMac/MemoWeaverPinnedPaneLayout.swift" \
  "$ROOT/Tests/PinnedPanesV0928Smoke.swift" -o "$TMP/pinned"
"$TMP/pinned"
swiftc -frontend -parse -swift-version 5 "$ROOT"/WorkOSMac/*.swift
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys,plistlib
r=Path(sys.argv[1]); w=r/'WorkOSMac'
plist=plistlib.loads((w/'Info.plist').read_bytes())
assert plist['CFBundleIdentifier']=='com.local.workos.notes'
assert plist['CFBundleShortVersionString']=='0.9.35' and plist['CFBundleVersion']=='68'
split=(w/'MemoWeaverPinnedSplitView.swift').read_text(); main=(w/'MainView.swift').read_text()
head=(w/'MemoWeaverEditorChrome.swift').read_text(); form=(w/'MemoWeaverCategoryCreationSheet.swift').read_text()
assert split.count('masksToBounds = true')==1 and 'split.insertArrangedSubview(pane, at: index)' in split
assert 'state.applyPreferredFrames(in: split)' in split and 'split.needsDisplay = true' in split
assert 'reconcileArrangedPanes(in: split)' in split and 'applyPreferredFrames(in: splitView)' in split
assert 'completedDivider == .list' in split and 'completedDivider == .right' in split
assert 'if completedDivider == .list' in split and 'if completedDivider == .right' in split
assert main.count('.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped()')==3
assert 'bookFilter.frame(minWidth: 0, maxWidth: .infinity)' in main
assert 'typeFilter.frame(minWidth: 0, maxWidth: .infinity)' in main
for source in [main,head]:
    assert 'Button("새 노트북 만들기…", systemImage: "plus")' in source
    assert 'Button("새 종류 만들기…", systemImage: "plus")' in source
    assert 'MemoWeaverCategoryCreationSheet(kind: "book")' in source
    assert 'MemoWeaverCategoryCreationSheet(kind: "type")' in source
assert 'localizedCaseInsensitiveCompare' in form and 'model.createCategory(kind: kind, name: name)' in form
assert 'onCreated(created.id)' in form and 'onCreated(found.id)' in form
# Data format / bundle ID / storage implementation were not migrated.
assert (w/'MemoWeaverAttachments.swift').exists() and (w/'Storage.swift').exists()
print('PASS v0.9.28 source contracts: clipping, pinned native divider, reliable show/hide, category actions on both menus')
PY
if [[ "$(uname -s)" == Darwin ]]; then
    echo 'macOS GUI divider/clipboard behavior must still be verified in the running app.'
else
    echo 'SKIP macOS AppKit runtime: Linux environment, source parsing and sizing tests passed.'
fi
