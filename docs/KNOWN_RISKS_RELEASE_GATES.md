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
| Official Mermaid/Markmap JS bundle | Retained unchanged; locked audit reconstruction and 4,233 library statements verified | Original legal files, source access and evidence limits: THIRD_PARTY_LICENSE_AUDIT_2026-10-29.md |
| Source licensing | Apache-2.0 retained; owner selected Copyright (c) 2026 Rayeonjin | NOTICE/COPYRIGHT identify the project holder; upstream rights and dependency inventory remain separate |
| Brand name / logo | Policy draft only | Confirm creator permissions and optional trademark clearance/filing |
| Public binary release | Not planned | Do not distribute .app as notarized or supported official binary |

## Public source access decision

On 2026-10-29 the owner explicitly requested public source visibility for
anonymous downloads from the work computer. No binary release was created.
The dependency-license inventory remains open; public availability does not
certify that inventory, ownership review or manual GUI acceptance.

## Dependency license audit (2026-10-29)

Original legal files, 171 npm package/version records (including conservative
closure/type/tool coverage), eight upstream ELK Java source/build dependency
records, EPL source-availability information and integrity checks are now
preserved under `THIRD_PARTY_LICENSES/`. DOMPurify uses the Apache-2.0 option.
ELK remains EPL-2.0; EMF GWT remains EPL-1.0. This does not relicense those
components as project-owned Apache code.

A frozen `npm ci --ignore-scripts` reconstruction matches all 4,233 retained
library statements by lexical-scope-aware AST comparison. Only the final local
bridge differs and is excluded. No renderer JS asset was replaced.

The missing original producer build receipt is not recreated or falsely
claimed. Source-map/declared-closure packages are conservative notice coverage;
exact embedded helper versions and the original upstream GWT build are not
independently proven. FastDom/boolbase declarations are preserved where their
npm archives omit standalone license files. Read
`THIRD_PARTY_LICENSE_AUDIT_2026-10-29.md` for the complete scope and limitations.
Automated integrity/source/packaging checks are engineering evidence, not a
legal warranty or native GUI acceptance.

## Deferred issues

- Schedule is supported but should not be considered notification-complete
  without real macOS testing.
- No project-owned cloud backend or external credentials should be required.
- App/username data paths with legacy `WorkOS` tokens are intentional and
  must not be renamed without separately tested migration.
- Builds now carry project legal documents and the Licenses/ directory;
  standalone HTML includes consolidated legal texts and source access in
  non-executable JSON. Do not remove these when redistributing.
