# v0.9.69 · Build 102 — 2026-11-15

Memory-map exploration now supports local d3-force automatic layout, native zoom,
panning and node dragging while preserving business relationships and evidence.

- Bundle exact ISC d3-force 3.0.0 plus its three pinned dependencies offline.
  Existing diagram assets are unchanged. Original notices are retained.
- Compute bounded layout in JavaScriptCore on a background queue, passing only
  node IDs, accepted edges and coordinates. No web view/network/AI/body transfer.
- Mouse wheel or trackpad pinch zooms; precise trackpad scrolling and background
  dragging pan. Buttons provide zoom, fit and layout reset. +/- and 0 work while
  the map has keyboard focus. Zoom is anchored under the cursor.
- Drag a node to hold its presentation position; layout reset releases those
  positions. Pins/camera are transient UI state, never stored as business links.
- Native accessible node/relation controls keep selection and evidence details
  available. Directional AI relations show arrows. Zooming out reduces label noise.
- Keep pending initial layout running on simple clicks; cancel/recompute only
  for actual node dragging. Retain native accessibility elements while visible.
- Reject stale layout responses after graph changes/removal. Keep the 110-node
  display bound and all existing source/review/manual-link behavior.

Gate: `./install-v0.9.69.sh --verify`.
Actual evidence/limits: [D3 map](../D3_MEMORY_MAP_2026-11-15.md).
