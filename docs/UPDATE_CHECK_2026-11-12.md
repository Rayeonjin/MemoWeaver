# Manual update checking — 2026-11-12

The owner requested the update-check feature used in Catoshi. Its reference
behavior is manual-only GitHub checking, version comparison and a release link.
MemoWeaver implements that behavior independently with Foundation and SwiftUI.

GitHub inspection before implementation found no Releases and three existing
QA tags. Therefore this checker examines both public `/releases` and `/tags`,
chooses the newest valid semantic version and prefers a Release page on a tie.
It does not confuse an existing older Release with a newer QA source tag.
See [GitHub's release API](https://docs.github.com/en/rest/releases/releases).

## Boundaries

- Settings → App information → Check for Updates. Constructing the view or
  launching the app does not initiate a request. No automatic download/install.
- Only fixed public `api.github.com/repos/Rayeonjin/MemoWeaver/...` endpoints.
  No authentication/cookies, note content, current-version transmission, database
  paths, files or AI requests. GitHub necessarily receives a normal web request.
- Redirects rejected; API-supplied `html_url` and pagination URLs are never opened.
  Version/source links are generated under the canonical GitHub repository.
- At most five pages per feed, 100 items/page, 10s request/20s resource timeouts
  and 4 MiB decoded response-size limit per page. Incomplete feeds are errors.
- Bundle `MemoWeaverReleaseTag` supplies `v0.9.67-qa` so the installed QA build
  compares equal to its QA tag. Future releases must update that key with the
  version/build and matching publication tag. Metadata does not alter storage.
- Source ZIP links do not install an app. Users follow the downloaded source's
  README and preserve a separate data backup before replacing their installation.

## Validation

Unchanged v0.9.66 baseline: full verification passed before edits.

New deterministic tests: PASS for semantic/QA/beta ordering, build metadata,
invalid versions, release/tag precedence, later pages, fixed endpoint/link
origins, absent body/credentials, empty/malformed/offline/403/429/404/500 errors,
incomplete lists, no request on construction, duplicate check suppression and
old cancelled response generation protection.

Final verification: all eight groups in `./install-v0.9.67.sh --verify` passed,
including the isolated native navigation/editor harness, followed by a complete
arm64 macOS compile/link and ad-hoc signature. Installed v0.9.67 / Build 100 at
`~/Applications/MemoWeaver.app`; its executable hash matches the verified build.
Strict signature and packaged third-party legal-file verification passed.

Actual installed UI: App information displays v0.9.67 / Build 100 and the manual
button. Clicking it reached GitHub and correctly displayed the request-limit
error with a direct GitHub fallback link. The current network's anonymous API
quota was exhausted; successful live comparison was not verified at this point.
Newer/current/ahead comparisons and failure/cancellation behavior passed the
deterministic tests above. No automatic installer was exercised or added.

Before/after read-only checks of the existing store found identical note IDs,
raw JSON hash and counts across notes, archives, schedules, notebook membership,
virtual memories and memory links. SQLite `quick_check` returned `ok`. Private
pre-install data/preferences and prior app backups remain outside public Git.
Public-source preflight passed; no binaries or private QA artifacts are published.
Existing human IME, notification and live Ollama acceptance limits are unchanged.
