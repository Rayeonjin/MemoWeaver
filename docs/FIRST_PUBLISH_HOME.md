# First publication / home Mac checklist

This repository is intended to be PUBLIC so a second computer can download and
build without signing into GitHub. Only the owner's home computer should push.

## Current setup (2026-10-29)

`https://github.com/Rayeonjin/MemoWeaver` is the public source repository, opened
by the owner's explicit request for anonymous downloads on 2026-10-29.
The original v0.9.64 QA source is preserved in the first commit/tag; reviewed
stability fixes are a subsequent commit. Do not recreate this repository.
Use `docs/GITHUB_SETUP.md` for the current clone and weekly update commands.
The checklist below records outstanding review items; public visibility does
not mark those items complete.

## Legal gates: read BEFORE public uploading

[ ] Confirm rights to relicense the project's original Swift and JS glue code.
[x] Owner selected `Copyright (c) 2026 Rayeonjin`, matching Catoshi.
[x] Owner retained the existing Apache License 2.0 direction; NOTICE identifies Rayeonjin.
[ ] Approve TRADEMARKS.md and reserve the brand/logo separately, understanding
    a policy file alone does not replace registration or guarantee exclusivity.
[x] Collect current bundled-runtime evidence, conservative dependency closure,
    original license/notice files and EPL source access. See the 2026-10-29 audit.
    This evidence does not constitute an original build receipt or legal warranty.
[ ] Replace any provisional original project URL with the actual GitHub URL.
[ ] Check for private data, credentials, screenshots and proprietary assets.
[ ] Check whether any non-owner contributed code requires permission/credits.
[ ] Do not describe v0.9.64 as a tested production release.

## Prepare repository

Create an EMPTY public GitHub repository named `MemoWeaver` on the home computer
(without auto-creating a README/LICENSE/.gitignore). Unzip the public source
package's `MemoWeaver/` directory into a normal working location. From there:

```bash
./tools/public-source-preflight.sh
git init -b main
git add -A
git status --short
git -c core.whitespace=-blank-at-eol,-blank-at-eof diff --cached --check
git commit -m 'chore: import MemoWeaver v0.9.64 QA baseline'
git remote add origin https://github.com/ACCOUNT/MemoWeaver.git
git push -u origin main
git tag -a v0.9.64-qa -m 'Initial source baseline; Mac QA pending'
git push origin v0.9.64-qa
```

Replace `ACCOUNT` with your GitHub user or organization handle. The first import retains historical baseline whitespace exactly; the Git
check above suppresses warnings on legacy trailing-space/EOF formatting for
that initial import only. Later weekly changes should use a normal whitespace
check and avoid introducing such formatting. GitHub will
require authentication for this initial push. Afterward, no authentication is
needed for anyone to anonymously read/clone/pull the public repository.

For a Mac without Git CLI (`git init -b main` may be unavailable), use
`git init`, `git branch -M main`, then the remaining commands.

**Private backup folder and the original full source ZIP are NEVER uploaded.**
There are no `.git` credentials or author identities embedded in this archive.

If license/SBOM audit is not complete, hold off public posting rather than
claiming the repository is legally ready. The source tree is packaged for a
reviewed first commit, not a legal compliance certification.
