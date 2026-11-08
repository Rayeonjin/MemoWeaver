# v0.9.66 · Build 99 — 2026-11-08

QA candidate; three reproduced stability-review findings from v0.9.65.
No schema, identity, note-source or attachment-path migration.

- On navigation, close wiki and slash completion on the actual editor, release
  its own window's first responder, and prevent deferred completion/focus actions
  from modifying or refocusing a hidden editor. Return to the same native editor
  with source, caret and undo intact. IME preflight also checks the main window
  when a popover owns the key window.
- Prefer a saved wiki target binding over a coincidentally equal imported note ID.
  Missing/deleted bound targets remain unresolved instead of opening another note.
- Exclude inline dollar math, display dollar math and math/code fences from wiki
  references; preserve Unicode UTF-16 offsets and physical CRLF line numbers.
  Old optional binding fields are retained without rewriting user source.

Validation and remaining manual gates: `../WIKI_STABILITY_2026-11-08.md` and
`MAC_ACCEPTANCE_v0.9.66.md`. Use `./install-v0.9.66.sh --verify` from the repository
root. The functional script names from 0.9.65 remain reusable; old hash/version
baseline checks are not rewritten.

Rollback: rebuild the preceding source tag and retain the existing data directory.
The fixes do not destructively migrate stored data. No app installation is part
of verification, and mobile/QR remains deferred.
