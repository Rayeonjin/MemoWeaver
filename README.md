# MemoWeaver

> Local-first macOS notes, Markdown when helpful, and optional AI-assisted
> connections between ideas. **Current baseline: v0.9.64 / Build 97 (QA candidate).**

**바로가기:** [설치·빌드](#build-from-source-macos-14) · [문서 안내](docs/README.md) · [최신 변경 사항](docs/releases/CHANGELOG_UNRELEASED.md) · [테스트 안내](scripts/README.md) · [라이선스 고지](THIRD_PARTY_NOTICES.md)

The development repository is [Rayeonjin/MemoWeaver](https://github.com/Rayeonjin/MemoWeaver)
and is **public** for anonymous source downloads, as requested by the owner.
[Download the latest source ZIP without signing in](https://github.com/Rayeonjin/MemoWeaver/archive/refs/heads/main.zip).
Third-party notices, EPL source access and the retained-asset audit are recorded
in [the license audit](docs/THIRD_PARTY_LICENSE_AUDIT_2026-10-29.md).
Manual GUI acceptance remains pending; source availability is not a compliance
warranty or production-release sign-off.
The unreleased stability changes passed the native build and current automated checks; see
[validation evidence](docs/STABILITY_REVIEW_2026-10-29.md).

This is the source repository for MemoWeaver. It is also used for weekly
version control and development with Codex. It is **not** a public, notarized
`.app` distribution; the current source is not yet certified by native macOS
GUI acceptance testing.

## Design goals

- Capture notes quickly. Never let formatting tools or optional AI block writing.
- Keep the original Markdown/plaintext content and notebook relationships safe.
- Search and reconnect information later, rather than requiring manual taxonomy.
- Preserve a four-zone native workspace: navigation rail, note list, editor,
  auxiliary preview/references/AI pane.
- Operate locally. Rendering scripts are bundled; Ollama integration is optional.

## Build from source (macOS 14+)

Apple Command Line Tools (CLT) are required; a paid Apple Developer Program
membership or full Xcode installation is **not** required for the existing CLT
build path. First install CLT, if necessary:

```bash
xcode-select --install
```

Download a ZIP from GitHub or clone this repository. From the project root:

```bash
chmod +x build.sh install-v0.9.64.sh backup-before-real-use.sh
./install-v0.9.64.sh --verify   # tests + native build; DOES NOT install
```

The output is `build/Release/MemoWeaver.app`. Before installing any update to
an existing installation, quit MemoWeaver, run `./backup-before-real-use.sh`,
and keep the verified archive separate. Only after completing the relevant
`docs/releases/MAC_ACCEPTANCE_v0.9.64.md` and `docs/releases/MAC_ACCEPTANCE_v0.9.63.md` checks should an
owner elect to run `./install-v0.9.64.sh` (which changes the installed app).

A user working on a read-only computer may anonymously download or `git pull`
from this public repository. GitHub credentials are needed only on the home
computer used to push changes.

## Current quality status

- Cross-platform source, Foundation/SQLite, and regression checks have been
  run on previous development baselines. Those checks do **not** prove a
  complete macOS SwiftUI/AppKit build or real clicking/notification behavior.
- Native macOS build, Japanese/Korean IME, mouse-driven slash commands and
  math symbol controls, long-text input, split-pane re-open/resize, image paste,
  reminder alerts, and restore-from-backup must be validated on a real Mac.
- Existing app identifier `com.local.workos.notes` and data directory
  `~/Library/Application Support/WorkOS/` are intentionally preserved for
  compatibility. Do not rename these as cosmetic cleanup.
- The prebuilt JavaScript diagram bundle is retained unchanged. Original legal
  texts, a locked audit reconstruction, AST comparison and EPL source access
  are documented in `docs/THIRD_PARTY_LICENSE_AUDIT_2026-10-29.md`. Read its
  evidence limits before treating source or binaries as a cleared release.

## Use, attribution and brand

Copyright (c) 2026 **Rayeonjin**. See [COPYRIGHT.md](COPYRIGHT.md).

Project-owned original code is licensed under **Apache License 2.0**
(see `LICENSE`). Other authors' and dependencies' rights remain governed by
separate licenses. Redistributions must retain the applicable copyright and
license notices and the attribution in `NOTICE` where required. A derivative
may have a new product name and may be commercial; we ask that its documentation
acknowledge its origin in MemoWeaver.

**The MemoWeaver name and logo are not granted for rebranding a derivative.**
See `TRADEMARKS.md` and `BRAND_ASSETS.md`. This is a project policy, not a claim
that the name has already been registered as a trademark.

The project copyright-holder attribution and canonical repository are recorded
above. Rights provenance and legal-release review remain separate from the engineering
license inventory; see `docs/FIRST_PUBLISH_HOME.md` and the license audit.

## Development

For Codex, read `AGENTS.md` and `docs/LATEST_HANDOFF_SUMMARY.md` first. Work is
organized as one quality-controlled update per week. See
`docs/WEEKLY_CODEX_PLAYBOOK.md` and `docs/RELEASE_CHECKLIST.md`.

This repository does not include personal notes, SQLite databases, backups,
Ollama model weights, API keys, or any proprietary signing certificate.

## Repository layout

```text
MemoWeaver/
├── README.md                 # 프로젝트 소개와 설치·빌드 안내
├── build.sh / install*.sh    # 기존 빌드·설치 진입점
├── WorkOSMac/                # macOS 앱 소스
├── Tests/                    # Swift·Python 회귀 검사 코드
├── scripts/
│   ├── tests/                # 버전별 테스트 실행 스크립트
│   ├── renderers/            # 개발용 렌더러 준비·이전 도구
│   └── diagnostics/          # 진단 도구
├── docs/                     # 개발·운영·감사 문서
│   └── releases/             # 변경 이력과 버전별 수용 검사
├── tools/                    # 소스·라이선스 검증 도구
├── QA/                       # 검증용 해시 기록
├── Vendor/                   # 렌더러 소스 및 감사 재구성 자료
└── THIRD_PARTY_LICENSES/      # 외부 라이브러리 원문 고지
```

최상위에는 README와 빌드·설치·라이선스 진입점을 유지합니다.
기존 `./install-v0.9.64.sh --verify` 명령은 그대로 사용할 수 있습니다.
