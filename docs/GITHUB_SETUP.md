# GitHub setup — 2026-10-29

Repository: https://github.com/Rayeonjin/MemoWeaver (PUBLIC, owner-authorized anonymous source access).
Local Git root: the `PUBLIC_REPOSITORY/MemoWeaver` folder of the transfer.
Transferred from the original personal repository to the `Rayeonjin` organization
on 2026-10-29 at the owner's request; commit history and tags are retained.

Default branch: `main`. The root transfer folder and `PRIVATE_KEEP_OFF_GITHUB`
are outside Git. Build results, app bundles, user databases, attachments,
backup archives and credentials are excluded from source tracking.

## History

- `v0.9.64-qa`: original v0.9.64 / Build 97 source before stability edits.
  This QA tag is not a production stability certification.
- `weekly/2026-10-29-stability`: reviewed stability/performance changes and
  native build evidence, fast-forwarded into main.
- `weekly/2026-10-29-github-setup`: repository metadata and source scanning.

Commit identity is configured only in this repository as `feelbest` with the
GitHub-provided no-reply email; no personal email is published. HTTPS Git uses
the authenticated GitHub CLI/keychain. No token is stored in source or remote URL.

Local settings: `pull.ff=only`, `fetch.prune=true`, `core.autocrlf=input`.
No automatic Actions workflow or binary release is configured. App compilation
and tests run locally with `./install-v0.9.64.sh --verify`.

## Another Mac

No GitHub login is needed to download the source ZIP or clone/pull this public
repository. Other computers remain read-only under project policy.

Source ZIP: https://github.com/Rayeonjin/MemoWeaver/archive/refs/heads/main.zip

Unzip, open Terminal in the extracted folder and run the verification below.
The ZIP contains source code; it must be compiled on macOS before running.

```bash
git clone https://github.com/Rayeonjin/MemoWeaver.git
cd MemoWeaver
./install-v0.9.64.sh --verify
```

## Weekly changes on the home Mac

```bash
git switch main
git pull --ff-only
git switch -c weekly/YYYY-MM-DD-topic
# Make the focused change and run its checks.
./install-v0.9.64.sh --verify
./tools/public-source-preflight.sh
git add -A
git diff --cached --check
git commit -m 'fix: describe the change'
git push -u origin weekly/YYYY-MM-DD-topic
```

Review before fast-forward merging to main. Never force-push or rewrite main.
The owner authorized public source visibility on 2026-10-29 to allow downloads
at work without login. This decision does not mark the pending dependency
license inventory or manual GUI acceptance complete; see
`KNOWN_RISKS_RELEASE_GATES.md`. No binary release is published.
