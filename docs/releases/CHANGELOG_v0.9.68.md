# v0.9.68 · Build 101 — 2026-11-14

The memory map now emphasizes business context rather than similar wording.

- Remove all embedding-only edges and the map similarity threshold slider.
  Embeddings still discover candidates for analysis/search; they never establish
  a business relationship. Map generation no longer compares all vector pairs.
- Display current source-checked AI relationships and existing human links.
  Relationship labels can be selected to inspect the type, direction, explanation,
  exact quotations from both documents and read-only original windows.
- Start/cancel the existing selected-record relationship analysis from the map.
  Opening the view itself does not introduce a new AI request.
- Record a type/reason for new human links. Preserve old links and their data;
  never fabricate quotes or AI conclusions for a manual connection.
- Keep independent AI evidence even when the same pair has a human link. Hiding
  an AI interpretation preserves that human link. Source changes invalidate the
  AI interpretation until re-analysis.
- Reuse review/restore, source revision checks and import/export formats. No
  database migration, editor replacement or renderer/library changes.

Validation and limits: [evidence](../BUSINESS_MEMORY_MAP_2026-11-14.md).
