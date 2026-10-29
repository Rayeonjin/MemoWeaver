# Codex instructions for MemoWeaver

You are maintaining a long-running, local-first macOS notes app, not building
an IDE, task manager, or an AI-first chat app. **Start with the current sources,
not old changelogs.** The baseline is v0.9.64 / Build 97 (2026-10-28), a QA
candidate, not a production-certified release.

## On every new session

1. Read `README.md`, `docs/LATEST_HANDOFF_SUMMARY.md`,
   `docs/WEEKLY_CODEX_PLAYBOOK.md`, and `docs/KNOWN_RISKS_RELEASE_GATES.md`.
2. Read the current source files relevant to the request before writing code.
3. Check `git status --short`; preserve uncommitted work and existing notes.
4. Plan one small weekly release: scope, safety boundary, evidence, and rollback.
5. Do not silently implement unrelated features or redesign approved UX.

## Product constraints

- Basic editing, Korean IME composition, selection, caret, undo, autosave,
  error recovery, and clipboard input always take priority over optional tools.
- Four native zones: 52pt rail | preferred-width note list | flex editor |
  preferred-width auxiliary pane. Keep the per-pane native unified toolbar
  aligned to the actual split boundaries. Opening panels must not steal saved
  preferred widths or drop focus/caret/undo history.
- Maintain the left list toggle next to the editor title and a right auxiliary
  toggle that remains accessible even when the auxiliary pane is closed.
- Preserve the 30pt single-line insertion toolbar. Do not add everyday
  Markdown B/I/H/list buttons. Use snippets/tools only for hard-to-type forms.
- Slash `/` command selection must remain keyboard AND mouse usable.
- Math symbols: preserve 7 categories and all 99 source snippets; keep
  enlarged legibility without replacing the whole established UI pattern.
- Prioritize readable UI, first-click tooltips, and one-step common actions.

## Data contract (P0)

NEVER mutate real user data from tests. Use temporary database and isolated
application-support directories only. App bundle identifier must remain
`com.local.workos.notes`; live data path must remain
`~/Library/Application Support/WorkOS/` and legacy UserDefaults keys must be
kept intact. Retain all note IDs, notebook memberships, virtual memories,
attachments and relative paths, SQLite migrations, JSON backward imports,
local search, historical TXT, and manual-vs-AI relations.

Do not replace `NSTextView`, `NSSplitView`, or their established input/width
calculation paths as a shortcut. Do not reintroduce dynamic
`NSTrackingSeparatorToolbarItem`: it caused an actual SIGABRT in v0.9.42.
A schema change requires a separate versioned transaction, roundtrip tests,
backups, and explicit user approval. No silent destructive migrations.

## AI and third-party contracts

- Ollama/embeddings optional. No remote HTTP dependence for core editor.
- Keep offline KaTeX/Mermaid/Markmap resources working. Do not rebuild or
  replace the official diagram bundle casually; it lacks a complete locked
  dependency manifest and transitive-license audit.
- Preserve project provenance in `NOTICE`, Apache 2.0 `LICENSE`, and separate
  library rights in `THIRD_PARTY_NOTICES.md`. Do not present MemoWeaver source
  license as covering upstream third-party assets.
- Reserve product names and icon under `TRADEMARKS.md`/`BRAND_ASSETS.md`.
  Factual attribution is allowed; confusing derivative branding is not.

## Mandatory validation before proposing a weekly update

- On Mac, start with `./install-v0.9.64.sh --verify` for the baseline.
  For later versions, update the versioned script, then run `--verify` first.
- Run latest relevant regression suites including SQLite backups/notebooks,
  editing hot path, pane ratios, offline preview, clipboard and symbols.
- Test native GUI: light/dark, multiple window widths and 4 pane visibility
  states, rapid toggle and resizing, real Korean IME, mouse/keyboard controls,
  paste/drop, long note, preview, reminder + notification permissions.
- Confirm exported JSON restores, including planner schedules, using TEST data.
- Record **actual tests run** vs NOT RUN. Linux Swift parse is NOT a Mac build.
- Run `tools/public-source-preflight.sh` before publishing a public Git commit.
- Package the entire source and current summary if transferring out of Git.

## Weekly release and Git policy

- The user's **home computer is the only authorized write/push environment**.
  Other computers use anonymous clone/pull/download and build locally.
- Use `weekly/YYYY-MM-DD-topic` work branches; main should remain recoverable.
- Do not force push to main or rewrite history. Add concise versioned changelog,
  Mac acceptance checklist, and an updated handoff summary.
- Increment version/build only when preparing an actual release. Maintain
  `v0.9.64-qa` as the baseline tag if desired, NOT an assertion of stability.
- Never bundle .app build outputs, user SQLite, note data, screenshots with
  private content, keys, credentials, or private historical ZIPs into GitHub.
- Respect license adoption and trademark owner review before public upload.

When uncertain, report the risk and keep the tested original behavior.
