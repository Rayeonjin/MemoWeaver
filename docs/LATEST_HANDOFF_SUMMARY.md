# MemoWeaver / latest developer handoff

**Original source baseline:** v0.9.64 / Build 97 (2026-10-28). First GitHub
source-control handoff: 2026-10-29. The original transfer was byte-identical to
its source ZIP. The current checkout includes an unreleased stability update
on 2026-10-29; see `../CHANGELOG_UNRELEASED.md` and
`STABILITY_REVIEW_2026-10-29.md`. Version/build remain unchanged until an actual
release is prepared. The original manifests and private source ZIP are retained.

Git was initialized on 2026-10-29 after the stability work. The original source
is preserved as `v0.9.64-qa`; stability and GitHub setup are separate commits.
The remote is `https://github.com/Rayeonjin/MemoWeaver.git`. The owner subsequently
authorized PUBLIC visibility on 2026-10-29 to download sources at work without
GitHub login. See `GITHUB_SETUP.md`. The current dependency audit is documented
in `THIRD_PARTY_LICENSE_AUDIT_2026-10-29.md`; manual GUI acceptance remains pending. No app installation was performed.

On 2026-10-29 the owner selected the same copyright-holder attribution as
Catoshi: `Copyright (c) 2026 Rayeonjin`. MemoWeaver retains Apache License 2.0;
Catoshi's separate community license was not adopted. `COPYRIGHT.md` clarifies
scope and third-party exceptions. The build now includes the project's LICENSE,
NOTICE, COPYRIGHT and brand policy documents alongside third-party notices.

## Third-party audit update — 2026-10-29

`THIRD_PARTY_NOTICES.md` now indexes original legal texts for 171 npm version
records (runtime evidence plus conservative dependency/type/tool coverage),
eight ELK Java source/build dependencies and embedded contribution banners.
DOMPurify selects Apache-2.0; EPL-2.0 ELK and EPL-1.0 EMF source access is
preserved. The original two JavaScript assets remain byte-identical. A locked
reconstruction matches all 4,233 library statements; only the final local app
bridge is excluded. This is not the missing original build receipt.

The build ships Licenses/ and standalone HTML carries exact legal/source text
as non-executable JSON. The new offline license/export regression is part of
`--verify`. Optional Node/npm audit tools never run during ordinary app use.
All 13 installer QA suites, full native app compile/link/sign, strict signature
verification and exact packaged legal-file comparisons passed. See
`THIRD_PARTY_LICENSE_AUDIT_2026-10-29.md` for evidence and limits.

## What this product is

A native, local-first Mac note app with natural Markdown authoring and optional
AI relationships between saved knowledge fragments. It is NOT primarily a
Markdown document IDE or calendar app. Smooth writing and durable data always
outweigh adding new visible tools.

## Implemented features

- Native four-zone editing workspace with stable split panes / native toolbar.
- Text editing, autosave and recovery, folders/notebooks including multi-notebook
  membership, note kinds, search and virtual memory relationships.
- Optional local Ollama Q&A and similarity analysis; manual/AI links separated.
- Local Markdown preview, KaTeX, Mermaid, Markmap, charts and code fences.
- Native image paste/drop, Markdown tables/Excel TSV conversions, JSON backup.
- Schedule/reminders incl. per-note multiple deadlines, done state, D-day,
  notification time rules; Mac notification behavior still needs real QA.
- Slash commands using keyboard/mouse; category-based math symbol chooser.

## Recent release history (highest version supersedes earlier decisions)

- 0.9.61 Build 94: insertion catalog (21 code languages and advanced Markdown),
  passive tooltip sizing, offline renderer, safe backup workflow.
- 0.9.62 Build 95: slash palette mouse route and 25pt math symbol chooser;
  initial GitHub licensing assessment.
- 0.9.63 Build 96: schedule regression tests, JSON restore preflight fix for
  `memoweaver-notes`, extra validation on planner import; no schema change.
- 0.9.64 Build 97: retained math symbol readability but restored category-first
  navigation and reduced popover size. Planner/persistence/AI unchanged.

## P0 data and GUI constraints

- Keep `com.local.workos.notes` and WorkOS app support storage path.
- Preserve existing SQLite tables and note IDs, multi-notebook joins, original
  Markdown, images/attachments, JSON compatibility, AI/virtual links.
- No dangerous blanket migrations, destructive tests against real data,
  or external network requirements in the default editor.
- Preserve `NSTextView`, native `NSSplitView`, first-click passive tooltip,
  editor caret and IME state; no dynamic tracking separator items.
- Keep one-line 30pt insertion toolbar and 7-category 99-symbol system.

## Quality / limitations

On 2026-10-29, the unreleased stability update passed all 12 current installer
QA suites and a full native arm64 SwiftUI/AppKit compile/link with ad-hoc
signature verification. Detailed evidence is in `STABILITY_REVIEW_2026-10-29.md`.
Human first-click/Korean IME, notification delivery, live Ollama, GUI and real
write-save-restart/restore acceptance remain NOT RUN.
`./install-v0.9.64.sh --verify` is the home Mac acceptance gate and DOES NOT
install or overwrite the existing app.

Before source publication: verify copyright holder identity, Apache 2.0 license
adoption, `NOTICE`/brand policy, no sensitive files, and full licensing of the
5.6MB JS bundle. The latter is an **open compliance gap**, not a sign-off.

## Next weekly session

1. From the home Mac: inspect `git status`, baseline source, and selected issue.
2. Make only one limited, testable update; regression-test it.
3. Confirm normal notes workflow, not just unit tests, with temporary data.
4. Produce changelog + real Mac acceptance notes, new release number/build,
   and update this handoff before merge/tag/push.
5. Read `docs/WEEKLY_CODEX_PLAYBOOK.md`; stay out of user's live DB.

The private transfer archive also contains the full 155K historical Korean
handoff and the exact original v0.9.64 source ZIP. Neither belongs in public Git.
