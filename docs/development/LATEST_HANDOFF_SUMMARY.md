## 저장소 폴더 정리 — 2026-11-16

최상위 파일을 19개에서 11개로 줄였습니다. 과거 설치 스크립트는
`scripts/install/legacy/`, 저작권·브랜드 문서는 `docs/legal/`, 기준 해시는
`Tests/baselines/`로 옮겼습니다. 개발 문서와 검토 기록은 각각
`docs/development/`, `docs/reviews/`에 모았습니다.
[폴더별 안내](../REPOSITORY_LAYOUT.md)에서 이전 위치와 새 위치를 볼 수 있습니다.

현재 설치·빌드·백업 명령, 앱 소스 경로, 데이터 경로, 버전은 그대로입니다.
빌드와 검사 도구가 새 문서 위치를 사용하도록 수정했으며, 앱 안의 고지 파일
이름과 법적 문서 원문, 외부 리소스, 기준 해시 명세는 바꾸지 않았습니다.

## 소개 이미지와 후원 안내 — 2026-11-15

README에 격리된 예시 데이터로 촬영한 편집·미리보기 및 기억지도 이미지를
추가했습니다. 예시 Markdown과 이미지 제작 기록도 `docs/examples/`와
`docs/images/`에 보관합니다. Catoshi README에 등록된 Rayeonjin의
Buy Me a Coffee·Ko-fi 링크를 같은 자발적 후원 취지로 연결했습니다.
앱 코드·데이터·라이선스·버전은 변경하지 않았습니다.

## 한국어 공개 문서 정리 — 2026-11-15

README를 Catoshi의 사용자 중심 구성에 맞춰 한국어로 정리했습니다.
설치·업데이트·백업 안내는 [INSTALL.md](../INSTALL.md)에 모았으며, 문서 색인과
GitHub 안내 및 v0.9.69 변경 이력도 한국어로 갱신했습니다. 새 설치는
`~/Applications`, 기존 공용 앱만 있으면 `/Applications`를 사용하는 현재
스크립트 동작을 명시했습니다. 앱 코드·버전·설치 동작·라이선스는 변경하지
않았습니다. 로컬 문서 링크와 공개 소스 검사, diff 공백 검사를 확인했습니다.
과거 검증 기록과 외부 라이선스 원문은 보존합니다.

## Current update — v0.9.69 / Build 102 (2026-11-15)

The memory map uses pinned local d3-force 3.0.0 for background coordinate
calculation and native AppKit drawing/gestures. Zoom, pan, node dragging, fit and
reset are presentation-only. Existing business edges, review, both quotations
and read-only source access are retained. No similarity edges, schema change,
web view, runtime network or note-body transfer to JavaScript. Read
[D3 map evidence](../reviews/D3_MEMORY_MAP_2026-11-15.md). Gate:
`./install-v0.9.69.sh --verify`: all twelve groups/full build passed, followed
by final accessibility/click-during-layout native checks/build. Isolated UI zoom/pan/drag/edge/source
inspection passed. Installed Build 102, checked controls/version and exact live
store hashes/counts unchanged. Pins/camera are transient; physical pinch and prior
live Ollama/real IME limits remain.

## Current update — v0.9.68 / Build 101 (2026-11-14)

Memory map edges now represent source-checked AI business relationships or explicit
human links. Embedding similarity remains candidate discovery only, never a map
edge. Relationship labels open details with both quotes, direction, review and
read-only originals. Human reason/type and independent AI evidence coexist.
See [validation](../reviews/BUSINESS_MEMORY_MAP_2026-11-14.md) and
[release notes](../releases/CHANGELOG_v0.9.68.md). Current gate:
`./scripts/install/legacy/install-v0.9.68.sh --verify`: all eleven groups and full native build passed.
Strict signature/legal copies passed. Installed at ~/Applications on 2026-11-15
following the owner's normal app shutdown and complete private backup. Actual
Build 101/map/return-to-notes UI verified; all audited data row hashes/counts
unchanged. Separate fixture click-through timed out; live Ollama unavailable.
No schema migration or note rewriting.

## Current update — v0.9.67 / Build 100 (2026-11-12)

Manual GitHub update checking is available in Settings → App information.
Read [release notes](../releases/CHANGELOG_v0.9.67.md) and
[validation](../reviews/UPDATE_CHECK_2026-11-12.md). Current gate:
`./scripts/install/legacy/install-v0.9.67.sh --verify`. Publish a matching version tag and keep the
bundle MemoWeaverReleaseTag synchronized. No automatic checks/install or schema
change. All eight verification groups and full macOS build passed. Installed
Build 100, verified actual manual-check/rate-limit UI, signature/legal copies
and unchanged existing note hashes/counts. Live successful comparison is limited
by the network's exhausted anonymous GitHub quota. Earlier acceptance/history is
preserved below.

## Current update — v0.9.66 / Build 99 (2026-11-08)

Three stability-review findings were addressed: completion lifecycle/focus on
navigation, bound target priority and math backlink exclusion. Read
[release notes](../releases/CHANGELOG_v0.9.66.md) and
[validation](../reviews/WIKI_STABILITY_2026-11-08.md). Current gate is
`./scripts/install/legacy/install-v0.9.66.sh --verify`; no schema migration or app installation.
The history below records the earlier 0.9.65 update and baseline.

## Current update — v0.9.65 / Build 98 (2026-11-05)

Desktop usability, four review fixes and manual wiki links/backlinks are now
implemented. Read [release notes](../releases/CHANGELOG_v0.9.65.md) and
[validation evidence](../reviews/USABILITY_UPDATE_2026-11-05.md) before using this candidate.
Current gate: `./scripts/install/legacy/install-v0.9.65.sh --verify`. Real IME/GUI acceptance is pending.
Mobile/QR work was explicitly deferred. No schema change or app installation.
The history below documents the earlier v0.9.64 baseline.

# MemoWeaver / latest developer handoff

**Original source baseline:** v0.9.64 / Build 97 (2026-10-28). First GitHub
source-control handoff: 2026-10-29. The original transfer was byte-identical to
its source ZIP. The current checkout includes an unreleased stability update
on 2026-10-29; see `releases/CHANGELOG_UNRELEASED.md` and
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
Catoshi's separate community license was not adopted. `docs/legal/COPYRIGHT.md` clarifies
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

## Repository layout update — 2026-10-30

Root test scripts moved to `scripts/tests/`; developer renderer tools moved to
`scripts/renderers/` and clipboard diagnosis to `scripts/diagnostics/`. Versioned
release notes and acceptance documents are under `docs/releases/`. README stays
at the repository root, with quick links and a directory map. `docs/README.md`
and `scripts/README.md` index the relocated material.

`./build.sh`, `./install.sh`, `./scripts/install/legacy/install-v0.9.64.sh --verify` and the backup
entrypoint remain at the root. Test scripts resolve the repository root from
their new location. App source, legal asset bytes and private-folder boundaries
are unchanged. Original baseline hash manifests intentionally retain the old
paths because they describe the original tag, not the reorganized checkout.

Validation: all 116 relocated shell scripts passed syntax checks; all 127
relocations and executable paths were verified; 182 previously valid Markdown
link targets were preserved. All 13 current installer suites, native app
compile/link/sign and packaged legal-resource comparisons passed in the new
layout. The generated log is `build/Logs/repository-layout-verify.log`.
No manual GUI behavior was changed or newly certified.

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
`./scripts/install/legacy/install-v0.9.64.sh --verify` is the home Mac acceptance gate and DOES NOT
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
5. Read `docs/development/WEEKLY_CODEX_PLAYBOOK.md`; stay out of user's live DB.

The private transfer archive also contains the full 155K historical Korean
handoff and the exact original v0.9.64 source ZIP. Neither belongs in public Git.
