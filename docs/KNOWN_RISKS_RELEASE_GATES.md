# Known risks and release gates (2026-10-29)

| Area | Current status | Required proof |
|---|---|---|
| Full macOS CLT build | PASS for unreleased 2026-10-29 development changes, arm64/macOS 14 target | All 12 suites + native compile/link/ad-hoc sign verified; see STABILITY_REVIEW_2026-10-29.md |
| Real GUI / Korean IME | NOT VERIFIED here | Manual native click, composition, undo, selection, split reopen tests |
| Math symbol mouse UI | Source QA only | Check category hover/click, insertion caret/undo and narrow width |
| Slash palette mouse use | Source QA only | Click on a command while editor retains correct caret/source |
| Reminder delivery | SQLite/date calculations tested | Notification permissions, actual alert and click-through on Mac |
| JSON restore | Source/SQLite test, latest-format preflight fix | Isolated user profile, test-only data, backup roundtrip |
| Data/attachments | Protected stable source | Real image paste/drop/export, database/attachment recovery |
| Official Mermaid/Markmap JS bundle | Bundled offline | Verify version provenance, locked dependencies, SBOM and license copies |
| Source licensing | Apache-2.0 proposal included | Owner adopts and verifies rights; NOTICE contains intended attribution |
| Brand name / logo | Policy draft only | Confirm creator permissions and optional trademark clearance/filing |
| Public binary release | Not planned | Do not distribute .app as notarized or supported official binary |

## Important active license blocker

`Vendor/official-diagrams/package.json` pins top-level Mermaid/Markmap but
no `package-lock.json`/build metafile is included. The local 5.6 MB JavaScript
bundle contains DOMPurify, Lodash, regenerator-runtime and other transitive
code. Its current `THIRD_PARTY_NOTICES.md` covers only a subset of actual
bundled libraries. The bundled tool is not proven reproducible.

Before public distribution, reconstruct the exact dependency tree if possible,
regenerate a locked SBOM/`--metafile`, check all source and binary licenses,
and include needed notices in both the source and any redistributed app.
Do NOT silently replace the known-working diagram bundle until Mac visual
regression has been performed.

## Deferred issues

- Schedule is supported but should not be considered notification-complete
  without real macOS testing.
- No project-owned cloud backend or external credentials should be required.
- App/username data paths with legacy `WorkOS` tokens are intentional and
  must not be renamed without separately tested migration.
- Future published build/installer should carry LICENSE and complete notices,
  not only `THIRD_PARTY_NOTICES.md`.
