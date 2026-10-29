# MemoWeaver

> Local-first macOS notes, Markdown when helpful, and optional AI-assisted
> connections between ideas. **Current baseline: v0.9.64 / Build 97 (QA candidate).**

The development repository is [feelbest/MemoWeaver](https://github.com/feelbest/MemoWeaver)
and is **public** for anonymous source downloads, as requested by the owner.
[Download the latest source ZIP without signing in](https://github.com/feelbest/MemoWeaver/archive/refs/heads/main.zip).
The complete third-party license inventory and manual GUI acceptance remain
pending; source availability is not a compliance or production-release sign-off.
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
`MAC_ACCEPTANCE_v0.9.64.md` and `MAC_ACCEPTANCE_v0.9.63.md` checks should an
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
- The prebuilt JavaScript diagram bundle has a **pending complete transitive
  dependency license inventory**. Review `docs/KNOWN_RISKS_RELEASE_GATES.md`
  before treating the source or any compiled binaries as a cleared release.

## Use, attribution and brand

For project-owned original code, the intended license is **Apache License 2.0**
(see `LICENSE`). Other authors' and dependencies' rights remain governed by
separate licenses. Redistributions must retain the applicable copyright and
license notices and the attribution in `NOTICE` where required. A derivative
may have a new product name and may be commercial; we ask that its documentation
acknowledge its origin in MemoWeaver.

**The MemoWeaver name and logo are not granted for rebranding a derivative.**
See `TRADEMARKS.md` and `BRAND_ASSETS.md`. This is a project policy, not a claim
that the name has already been registered as a trademark.

Before first publication, the project owner should confirm ownership rights,
select the definitive public author/holder credit, update the repository URL
and complete third-party compliance checks. See
`docs/FIRST_PUBLISH_HOME.md`.

## Development

For Codex, read `AGENTS.md` and `docs/LATEST_HANDOFF_SUMMARY.md` first. Work is
organized as one quality-controlled update per week. See
`docs/WEEKLY_CODEX_PLAYBOOK.md` and `docs/RELEASE_CHECKLIST.md`.

This repository does not include personal notes, SQLite databases, backups,
Ollama model weights, API keys, or any proprietary signing certificate.
