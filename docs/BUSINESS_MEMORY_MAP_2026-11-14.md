# Business relationship memory map — 2026-11-14

The owner wants records needed to understand/perform work, not similar wording.
The existing business-relation analysis is retained; a separate new AI pipeline
or force-directed graph redesign is outside this change.

## Behavior

MemoryEngine.graph emits only explicit human links and caller-validated AI
business relations. Vectors/threshold no longer create edges or clusters.
Related-candidate search still uses embeddings/lexical context without treating
those candidates as actual relationships. All-pairs vector work is removed from
the map drawing path. The existing 110-node and focused 8-neighbor bounds remain.

AI relationships preserve type, source/target, explanation and both quotations.
Allowed types, quote sizes, current source fingerprints and exact excerpt matches
are checked before display. Reviews can hide interpretations. Matching quotations
only verify textual evidence, not the truth of AI's business interpretation.

Map labels and a relationship list expose the detail panel. Human links retain
manual type/reason; independent AI evidence for the same pair is still visible.
Hiding the AI relation does not erase the manual link. Old manual links without
reasons remain intact and are explicitly identified as such. Evidence opens in
the existing read-only source reader. No evidence is invented for manual links.
The existing selected-record analysis can be started/stopped from the map.
No new automatic network calls or source edits are added by viewing it.

No storage schema, note JSON, existing links, backup format, editor or preview
engine is replaced. Rollback: rebuild the prior v0.9.67 tag; no reverse migration.

## Validation

Baseline v0.9.67 verification was started before edits. Foundation/core/notebook
checks passed; the sandbox could not access the test-only macOS PNG pasteboard.
Re-running that exact pasteboard suite outside the sandbox passed. The baseline
run stopped before native/full build; the prior published v0.9.67 build evidence
is retained separately. The new complete gate is run with normal macOS access.

New core tests passed: identical embeddings produce no edge; typed/directional
relation retains both quotes; separate incident stays unconnected; human link and
AI evidence coexist; stale source rejects evidence; negative relation stays off
map; existing JSON roundtrip retains both forms of relationship.

Final gate: all eleven groups of `./install-v0.9.68.sh --verify` passed, followed
by a complete native arm64 macOS compile/link and ad-hoc signature. Existing
navigation/undo, synthetic marked-text guard, clipboard, panes, backup, notebooks,
update checking, legal assets and offline preview regressions passed.

The isolated native fixture rendered the actual memory-map view in light/dark
at 1000/1400pt widths and verified read-only evidence opening without selection
or note changes, AI hide/restore, manual connection preservation and stale-source
invalidation. The fixture relations are parsed/stored synthetic results, not a
claim that a live LLM made the correct business judgment. A test restoration was
corrected to use the current saved note snapshot before restoring its body.

Packaged third-party legal files and strict app signature verification passed.
A separate click-through QA app could not be inspected because computer-use
launch timed out. No manual click-through acceptance is claimed for that app.
On 2026-11-15, the owner normally quit the remaining build-directory process.
The standard complete data archive and preferences backup succeeded, then the
verified v0.9.68 / Build 101 app was installed at ~/Applications/MemoWeaver.app.
The installer preserved the previous app. No running-process check was bypassed.

Actual installed-app computer use confirmed Build 101 in App information, the
business-relationship memory map (one existing note, zero relations) and return
to the unchanged editor/preview. No relation analysis or sample notes were added
to the live store. Both before/after read-only audits found identical counts and
complete row hashes for the audited notes, archives, schedules, notebook joins,
virtual memories, manual links and AI relation/fact tables where present.
SQLite quick_check returned ok. The installed executable hash matches the full
verified build; strict signature and packaged legal-file checks passed.
All data/preferences/app backups remain outside public Git.

The actual local Ollama endpoint (127.0.0.1:11434) was unavailable, including
outside the sandbox. Live business-relationship quality and real Korean IME
composition are not verified. No real notes were sent for AI tests.
