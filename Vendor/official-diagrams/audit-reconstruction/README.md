# Audit reconstruction, not a replacement renderer

This directory freezes the dependency graph used on 2026-10-29 to investigate
the retained `official-diagrams.js` asset. It does not replace the active
Vendor manifest or runtime asset. es-toolkit 1.52.0 is an explicit reconstruction
constraint: the later 1.53.0 resolves successfully but differs in actual code.

`npm ci --ignore-scripts` was tested in a new temporary directory. A scope-aware
AST comparison matches all 4,233 library statements, preserving properties,
literals, operators, statement order and lexical binding identity while allowing
minifier-selected bound names to differ. The final local MemoWeaver bridge is
excluded; its natural-width handling differs from the retained bridge, so the
reconstructed output must not be substituted for the deployed renderer.

The graph, integrity digests and comparison are evidence for the current audit,
not an original producer lockfile/build receipt. Upstream source maps and the
complete declared dependency closure provide conservative additional notices;
not every source-map/closure file is necessarily emitted into the output.

Run `../../../tools/license-audit/reproduce.sh` from this directory, or
`./tools/license-audit/reproduce.sh` from the repository root. The check needs
Node/npm and network access for npm ci. Normal application builds use the
retained offline assets and do not require npm or runtime network access.
