#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
MAIN="$ROOT/WorkOSMac/MainView.swift"
RULES="$ROOT/WorkOSMac/NotePreviewRules.swift"
grep -Fq '@AppStorage("memoweaver.rightPane.visibility")' "$MAIN"
grep -Fq 'setSidePaneVisible(!sidePaneVisible)' "$MAIN"
! grep -Fq 'onClose: { setSidePaneVisible(false) }' "$MAIN"
grep -Fq 'setSidePaneVisible(true)' "$MAIN"
if grep -Fq 'paneVisibilityOverride = ' "$MAIN"; then
    echo 'FAIL: mutable temporary visibility override came back' >&2
    exit 1
fi
grep -Fq 'current' "$RULES"
grep -Fq 'static let maximumRightWidth: CGFloat = 1_000' "$RULES"
grep -Fq 'MemoWeaverPinnedSplitView(' "$MAIN"
grep -Fq 'NSSplitViewDelegate' "$ROOT/WorkOSMac/MemoWeaverPinnedSplitView.swift"
grep -Fq 'splitViewDidResizeSubviews' "$ROOT/WorkOSMac/MemoWeaverPinnedSplitView.swift"
! grep -Fq '.frame(width: widths.right)' "$MAIN"
echo 'PASS side pane state persists; native NSSplitView and pinned/deferred widths preserve editor resizing'
