# v0.9.65 · Build 98 — 2026-11-05

QA candidate. This update keeps the SQLite schema, app identity and existing
note/attachment storage paths. Mobile/QR pairing is deferred by the owner.

- Keep the native editor mounted when switching between notes and Settings;
  commit pending changes before sidebar navigation, preserving source and undo.
- Apply pin changes immediately, without the body autosave's one-second delay.
  Metadata-only saves do not start content hashing/AI indexing.
- Create one editable Korean welcome note in an initially empty store. Deleting
  it or restoring an intentionally empty backup does not recreate the note.
- Show the actual editor/auxiliary ratio beside the divider during drag using
  an AppKit label, with final ratio and widths persisted after mouse-up.
- Add native `[[` completion (arrows/Enter/Escape and mouse), command-click
  opening, preview links, and incoming/outgoing references in the connection
  pane. Picker links store IDs; saved unambiguous title links retain ID bindings
  in note JSON through renames and backup roundtrips. Duplicate titles require
  choosing an explicit target. Code examples are excluded from backlinks.
- Reject incomplete image backups/restores, including image references in
  revision history. Old image-free JSON remains readable; existing local assets
  may satisfy an older backup's references. Code examples are not attachments.
- Preserve full archive lines in search chunks. Repair previously truncated
  3,500-character chunks from original text, retaining IDs/line ranges and
  invalidating only their obsolete embeddings.
- Move archive read/decoding/chunk preparation and import to a worker-owned
  SQLite connection; prevent simultaneous whole-database replacement. Prepare
  chunks before acquiring the write transaction; refresh only archive lists.
- Include metadata changes in history checkpoints and avoid identical repeats.
- Provide isolated native QA with independent DB, recovery files, preferences
  and disabled system-notification mutation. Original release checks stay frozen;
  `./install-v0.9.65.sh --verify` runs the current functional gates and full build.

Rollback: return to the preceding source commit, rebuild, and preserve all
current user data. The new wiki JSON fields are additive. The old editor will
show their source syntax as text. No destructive database migration is involved.
