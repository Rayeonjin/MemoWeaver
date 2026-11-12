# v0.9.67 · Build 100 — 2026-11-12

QA candidate. Add the owner-requested Catoshi-style manual update check to
Settings → App information. Implementation uses Foundation/SwiftUI only.

- Contact the fixed public Rayeonjin/MemoWeaver GitHub endpoints only after
  pressing Check for Updates. No startup/scheduled check or automatic installer.
- Compare public Releases and semantic-version tags, including QA/beta versions;
  MemoWeaver's existing QA source tags work even without GitHub Releases.
- Show newer/current/ahead results, prerelease labels and fixed-origin GitHub
  version/source ZIP links. Updating remains an explicit source-build workflow.
- Compare numeric versions/prerelease identifiers correctly and ignore build
  metadata precedence. Bundle release-tag metadata matches the published QA tag.
- Treat offline, HTTP failures/rate limits, malformed/empty/incomplete results as
  errors, never as an up-to-date result. Bound pagination and response size.
- Use an ephemeral session without cookies or credential storage. No note text,
  database path, account token or file is sent. Redirects are rejected.
- Cancel view-owned requests and ignore stale completion after cancellation or
  another request. This service never accesses the note store or AI queues.

Evidence: `../UPDATE_CHECK_2026-11-12.md`. Current gate:
`./install-v0.9.67.sh --verify`. No schema/data migration, third-party dependency
or renderer-asset replacement. All earlier IME acceptance limits remain.
