# d3-force memory map — 2026-11-15

Scope: improve graph placement/exploration without changing accepted business
relationships, exact source quotations, review rules, note storage or editing.

## Design and boundaries

Use exact npm UMD distributions of d3-force 3.0.0, d3-dispatch/quadtree/timer 3.0.1.
Downloads were verified against npm SHA512 integrity. These versions and original
ISC licenses already exist in the retained diagram audit; the new separate bundle
is independently hash/composition-checked. No existing renderer asset is rebuilt.

Native AppKit draws circles, titles, typed edges/direction arrows and accessible
node/relation controls. A stopped d3-force simulation runs 180 bounded ticks in
JavaScriptCore on a serial background queue. Timer callbacks are inert. The
solver receives only IDs, accepted edges, initial coordinates and transient pins.
No note bodies, document titles, evidence quotations, database or network APIs
are exposed to JavaScript. No WebView/CDN/runtime network dependency is added.

Native viewport math provides pointer-anchored 20–300% zoom, background drag,
trackpad pan/pinch, fit and reset. Mouse wheel zooms; precise two-finger scrolling
pans (Command/Control+scroll also zooms). A dragged node is held while the next
bounded layout adjusts its neighbors. Reset releases all transient pins. Camera
and pins are intentionally view-local; leaving the map may reset presentation.

Position calculation never adds/removes/retypes graph relationships. Existing
business AI/manual edges and their original source details remain the only edges.
Physics proximity is not a similarity/relevance judgment. No schema migration.
The current 110-node/focused 8-neighbor bounds remain. Drawing and hit testing use
the same transform; late/cancelled background results are generation-guarded.

## Validation

Unchanged v0.9.68: full eleven-group gate and native app build passed before edits.
New core test passed using the actual JavaScriptCore bundle: deterministic finite
positions, collision separation, held node positions, ID-as-data safety, rejected
dangling edges, empty graph, 110-node solve and viewport anchor/inverse/clamps/fit.
The first measured 110-node solve was approximately 0.7s outside the UI thread.
All twelve groups of `./scripts/install/legacy/install-v0.9.69.sh --verify` and the full native arm64
app build passed. After manual inspection found virtual accessibility elements
were not exposed correctly, their enabled state and retained stable identities
were fixed. A final interaction guard also ensures a simple click during initial
layout does not cancel the pending calculation; only actual node dragging cancels
and restarts settling. That regression runs in the real disposable test window.
The affected native regression suite and full app build were rerun successfully
on the final source, then the installed app was synchronized to that build.

Native tests exercised actual map event methods for zoom, background pan and
node drag/pins/reset, accessible relationship actions and stale-generation
rejection. Business edge IDs and both quotations remained identical. Existing
light/dark, two window widths, editor identity/undo, synthetic marked-text,
clipboard, backup/notebook and offline-preview regressions also passed.

A separately bundled interactive QA process used six synthetic notes and four
business edges, isolated DB and preferences. Computer use confirmed zoom buttons
and changing percentages, fit, background drag and node drag with edge retention,
relationship selection from the graph, both source quotes and the read-only
original window. The final accessibility tree exposed the native graph group,
node buttons and relationship buttons; clicking an edge opened the correct
explanation. Test-only QA apps were normally quit. Physical trackpad pinch was
not independently exercised; its native event path is implemented.

Installed v0.9.69 / Build 102 at ~/Applications/MemoWeaver.app after normal app
shutdown and complete private data/preferences backup. The prior app was retained.
Computer use confirmed the installed version, graph controls, 140% to 175% zoom,
full-map selection and fit back to 140%. No sample notes or AI analysis were
added to the live store. Before/after read-only audits found identical counts and
complete row hashes across the audited notes, archives, schedules, notebook joins,
virtual memories, human links and AI fact/relation tables where present.
SQLite quick_check returned ok. Installed executable hash matches the final build;
strict signature, packaged runtime/legal copies and public preflight passed.
Backups, QA apps, logs and screenshots remain outside public Git.

Existing real IME, live Ollama relationship quality and notification limits remain.
