# Stability update validation — 2026-10-29

Development changes based on v0.9.64 / Build 97, with version/build unchanged.
No Git repository was initialized; no commit/push or app installation occurred.
All database tests used temporary directory overrides. The application was not
launched against the owner's WorkOS data.

## Scope and safety boundary

Whole-database restore rejects duplicate collections and count mismatches;
new regression tests prove rollback preserves original notes and schedules.
Add-only legacy import semantics remain unchanged. Large backup file size is
checked before reading; initial restore validation runs off the main actor.
The SQLite replacement itself remains on the main actor with its existing
transaction and pre-change snapshot.

Note snapshots retain decoded metadata. Raw JSON remains canonical and unknown
fields survive; raw JSON reassignment refreshes the cache. Hash/equality ignore
only presentation caches and retain all original fields.

Markdown line checkpoints preserve original parsing results and invalidate
before AppKit text mutation; fallback/programmatic changes reset the cache.
The NSTextView, undo, IME and split-width paths were retained. Recovery now
compares all saved editable fields. New Markdown history retains bodyFormat,
and semantic history indexing respects it. Date filters use local dates.
AI response state uses a generation token to ignore canceled prior requests.

## Actual verification

- `./install-v0.9.64.sh --verify`: PASS on native arm64 macOS with CLT,
  targeting macOS 14.0; all twelve suites below completed before app compilation.
- Full app compiled and linked, then ad-hoc codesigned and signature-verified.
- Final `codesign --verify --strict --verbose=2`: PASS.
- Output: `build/Release/MemoWeaver.app` (arm64, development QA candidate).
- Unchanged SQLite schema statements, Info.plist identifier/version, original
  icon, KaTeX and official diagram assets compared against pre-change archive.
- Bash 3.2 empty arrays and CLT frontend argument ordering corrected. QA uses
  project-local module caches, including scripts with direct xcrun invocations.
- The macOS sandbox blocked iconutil; the identical icon conversion succeeded
  with approved native-service access. No icon or build fallback was substituted.
- Native clipboard smoke used a uniquely named test pasteboard, not the general
  clipboard. No user data directory was used by tests.

Completed suites:

- `test-review-stability.sh`
- `test-v0.9.64-schedule.sh`
- `test-v0.9.64-pointer-symbols.sh`
- `test-v0.9.64-toolkit.sh`
- `test-v0.9.64-live-preview.sh`
- `test-v0.9.64-optimization.sh`
- `test-v0.9.60-brand-data.sh`
- `test-v0.9.59-ratio-cycle.sh`
- `test-v0.9.60-editor-hotpath.sh`
- `test-side-preview.sh`
- `test-v0.9.51-notebooks.sh`
- `test-v0.9.27-pinned-paste-ui.sh`

The added stability suite checks duplicate notes/types/books/sources/events,
transaction rollback, a source count mismatch, JSON/schedule roundtrip,
oversized sparse-file rejection, raw JSON cache invalidation/value semantics,
unknown fields, local calendar boundaries and metadata-only recovery. Context
parity covers forward/backward caret offsets, 250 randomized Unicode edits,
and 12,000-line caret movement (200 moves / 200 partial-line scans).

Performance observation, synthetic 50-revision note (~6.6 MB raw JSON), default
-Onone compilation: the original notebookIDs accessor took ~1.54 seconds for
100 reads; the updated accessor took less than 1 ms. This is an accessor
microbenchmark, not an application-wide latency measurement.

Latest actual run: `PERF: notebookIDs 100 reads, rawJSON=6631509 bytes, 0.30803680419921875ms`

## Not run

Human GUI acceptance, Korean IME, notification delivery/permissions, live Ollama
stop/restart and production-size memory profiling were not performed. See
`../MAC_ACCEPTANCE_UNRELEASED.md`. Native compile/smoke success does not certify
these behaviors. Full third-party diagram licensing audit remains pending.

## Evidence and rollback

- Full QA/build output: `../build/Logs/stability-verify.log`.
- Compiler/signing diagnostics: `../build/Logs/swiftc-release.log`.
- Original protected-source manifest remains `../QA/v0.9.60-core-source.sha256`;
  current QA uses `../QA/review-stability-core-source.sha256` for reviewed edits.
- The private transfer folder contains `BEFORE_STABILITY_2026-10-29.tar.gz`,
  a full pre-edit source snapshot excluding generated build outputs. The exact
  original release ZIP is also preserved. Neither archive belongs in public Git.
- Rollback: discard the generated development app, then restore only the changed
  source/scripts from that snapshot. No database rollback/migration is needed
  because no installed app or real user data was modified.
