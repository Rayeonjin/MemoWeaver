# Unreleased stability update — 2026-10-29

Based on v0.9.64 / Build 97. Version/build unchanged; this is a development
candidate, not a new production release. No schema or identifier changes.

- Reject duplicate IDs in whole-database backup replacement and roll back if
  archive or note import counts differ. Add-only legacy import stays tolerant.
- Reject oversized JSON files before reading them. Run restore file reading
  and initial validation off the main actor; SQLite mutations stay serialized.
- Retain decoded note metadata between UI reads; invalidate on raw JSON changes.
- Cache Markdown context at line boundaries, invalidating from the edited line.
  Preserve existing NSTextView, IME, text, caret and undo paths.
- Detect metadata-only recovery drafts, retain Markdown revision format in new
  history and semantic indexing, and compare note filter dates in local time.
- Ignore stale AI answer/error/completion updates after stop and restart.
- Repair Bash 3.2 empty-array handling in current QA, pin CLT SDK/module caches,
  and add isolated regression coverage for these fixes.

Original `QA/v0.9.60-core-source.sha256` and original-transfer manifests remain
unchanged. Current installer checks use `QA/review-stability-core-source.sha256`
for reviewed storage/recovery edits; this is not an assertion of unchanged code.

See `MAC_ACCEPTANCE_UNRELEASED.md` for manual acceptance still required.
