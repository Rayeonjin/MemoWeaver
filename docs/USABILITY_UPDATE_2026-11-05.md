# Desktop usability and wiki links — 2026-11-05

Scope: four reviewed correctness/performance issues, sidebar/pin latency,
first-use guidance, measured drag ratios, and manual wiki links/backlinks.
The owner explicitly deferred mobile/QR work to the next update.

## Storage and interaction boundaries

No table/schema or app identifier changes. All note IDs, original archives,
attachments and existing notebook joins remain. Optional `wikiLinkTargets` in
raw note JSON binds typed labels to IDs; picker links are `[[ID|label]]`.
Reference counts reflect saved content. New links are never AI relationships.
A deleted target is unavailable, and duplicate title matches are not guessed.

The first-run marker uses the existing metadata table. Full replacement records
that initialization is complete even for an empty backup. Archive repair changes
only derived chunk text, preserving IDs and physical line pointers.

Import uses a connection created and destroyed on its worker executor. MainActor
connections never cross tasks. JSON replacement is blocked while import runs.
Normal writes remain transactional and SQLITE_FULLMUTEX/WAL are retained.

Image checks cover rendered Markdown attachment references in note/history
payloads, skip code examples, and retain legacy image-free import compatibility.
Incomplete imports abort and roll back; exports do not claim success.

The notes hosting tree stays mounted behind other sidebar routes. Sidebar
navigation commits first and clears the hidden editor's first responder. Ratio
feedback is a native label, so dragging does not cause per-move SwiftUI updates.

## Verification

Baseline v0.9.64 at the unchanged initial commit: all 13 installer suites and
full native arm64/macOS 14 compile/link/sign passed before edits.

Current release checks executed successfully:

- Seven current gate groups: legal/export notices, six Foundation/SQLite core
  executables, offline preview, pane-ratio policy, legacy/multi-notebook migration,
  AppKit clipboard/panes and the isolated native usability harness.
- Native harness: three Settings/notes roundtrips preserve the exact NSTextView,
  source and undo. Six deliberate 150ms polling waits plus transitions took
  about 0.94 seconds in the recorded run; this is not a general UI benchmark.
- Wiki completion/Enter inserts an ID link; pin state is committed after 100ms of event
  processing rather than the previous one-second debounce; backlinks update.
- Synthetic marked-text navigation guard; background TXT import allowed 58 UI
  heartbeats during the recorded run and preserved the mounted editor.
- Current edge-case smoke rerun after preview binding/math adjustments: PASS.
- Full final arm64/macOS 14-target compile/link/ad-hoc sign: PASS. Strict signature
  verification and byte-for-byte packaged legal-resource checks: PASS.
- Public-source secret/file preflight, its regression fixtures and diff whitespace:
  PASS.

The first combined gate reached the build but Swift correctly rejected a source
edited during compilation. Sources were then frozen and the entire final build
was repeated successfully (`build/Logs/release-0.9.65-build-final.log`). A temporary
host disk-space failure was resolved by removing regenerable build cache; it is
not recorded as a passing test. Historical attachment-suite dialect assertions
were not adopted as a current gate; current attachment regression is in
`UsabilityReleaseSmoke`.

Expanded native harness: PASS for light/dark, 1,000/1,400-point requested window
widths and all four list/auxiliary visibility combinations. The same editor
instance remained mounted and all visible panes retained positive widths.
The generated fixture screenshot was visually inspected (dark, 1,400-point
window, manual connections pane). This does not certify human mouse/IME input.
After this run, startup repair was narrowed to reload chunks only when a repair
actually occurred; the repair edge-case smoke and full app build were rerun.
The four-state/light-dark harness is `Tests/UsabilityNativeSmoke.swift`.

Before running `--verify`, allow enough free disk for Swift's module caches and
linking. The test harness briefly opens a window containing generated test notes.
No test screenshots, logs, application bundles or personal data are committed.

Human GUI/real Korean IME, live Ollama, notification delivery and real-device
mobile behavior are not certified by these tests. The native harness uses a
temporary DB/preferences/recovery location and disables system reminders.
