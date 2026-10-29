# One-update-per-week Codex workflow

## Home computer (ONLY place allowed to write / push)

```bash
cd MemoWeaver
git status --short
git pull --ff-only origin main
git switch -c weekly/YYYY-MM-DD-topic
```

Read `AGENTS.md`, `docs/LATEST_HANDOFF_SUMMARY.md`, any relevant source/tests
and previous Mac acceptance findings. Define a narrow change with a rollback
path. Make changes only on the branch. Avoid introducing more features just
because nearby code is visible.

Check current test script named for the updated version. For the initial base:

```bash
./install-v0.9.64.sh --verify
./tools/public-source-preflight.sh
```

`--verify` builds but DOES NOT install. Before replacing an installed app:

```bash
# Quit MemoWeaver first, and preserve the archive.
./backup-before-real-use.sh
# Only when real native GUI and data tests have passed:
./install-v0.9.64.sh
```

After testing a subsequent weekly release, update `Info.plist`, installer
script name, RELEASE/CHANGELOG/MAC_ACCEPTANCE docs and
`docs/LATEST_HANDOFF_SUMMARY.md`, only recording evidence from actual execution.

```bash
git add -A
git diff --cached --check
git commit -m 'fix: describe one focused improvement'
git switch main
git merge --ff-only weekly/YYYY-MM-DD-topic
git tag -a vX.Y.Z-qa -m 'QA candidate; native acceptance status documented'
git push origin main --tags
```

Never force-push or rewrite remote history. If tests are not passing or Mac
GUI remains unknown, keep the work on its branch, do not mark as stable.
A tag is a source reference, not evidence of a notarized or production app.

## Any other computer (NO GitHub login, no edits/push)

For first use, download the public source ZIP on GitHub or:

```bash
git clone https://github.com/ACCOUNT/MemoWeaver.git
cd MemoWeaver
./install-v0.9.64.sh --verify
```

Replace `ACCOUNT` with the actual public repository owner. Subsequently:

```bash
cd MemoWeaver
git pull --ff-only origin main
# Check README for this week's appropriate install-v*.sh script.
```

Building the source does not require GitHub login. NEVER put project access
tokens, user notes, app databases or backup archives in the repository.

## GitHub history strategy

- Begin at v0.9.64 / Build 97 (baseline). Do not import 100+ old release
  snapshots as individual commits: they are in private backup.
- Suggested first annotated tag: `v0.9.64-qa`, explicitly not `v1.0`.
- One weekly topic branch, one reviewed merge, one precise changelog entry.
- Build outputs `.app`, crash dumps, logs, local SQLite, screenshots with note
  content and downloaded models remain untracked.
