# Third-party licenses and copyright notices

Audit date: 2026-10-29. Project-owned MemoWeaver code remains Apache-2.0,
Copyright (c) 2026 Rayeonjin. The third-party components below retain their own
licenses and copyright holders; the project copyright does not apply to them.

## Files and evidence

- `THIRD_PARTY_LICENSES/` preserves original package LICENSE, NOTICE, COPYRIGHT,
  author and applicable Java-source header material without rewriting holders.
- `manifest.json`: npm package/version inventory, source URLs, integrity hashes,
  evidence class, license choice and original notice hashes.
- `maven-manifest.json`: eight conservative ELK Java source/build dependencies.
- `SOURCE_AVAILABILITY.md`: public source access for EPL-1.0 / EPL-2.0 components.
- `ALL_LICENSES.txt`: consolidated original notices carried by standalone HTML.
- `Vendor/official-diagrams/audit-reconstruction/`: frozen reconstruction graph
  and 4,233-statement scope-aware AST comparison. The local final bridge differs;
  the installed assets are preserved byte-for-byte.

DOMPurify's `(MPL-2.0 OR Apache-2.0)` is used under the Apache-2.0 option. Its
original dual-license text is preserved. ELK remains EPL-2.0, and EMF-for-GWT
source remains EPL-1.0; these are not relicensed as MemoWeaver-owned code.

KaTeX's standalone asset declares 0.16.27; Mermaid also includes KaTeX 0.18.10.
No separate KaTeX fonts, Ollama executable, AI model weights, Apple frameworks
or SQLite binaries are redistributed in this source/app bundle. macOS system
frameworks and SQLite are linked at runtime. The official JavaScript bundle
includes the original inline third-party banners reproduced under embedded/.

## Inventory interpretation

`audit-output` identifies a package contributing to the reconstruction output;
`upstream-prebundle-source-map` identifies code inside a published prebundle;
`embedded-*` is direct original-asset evidence. `conservative-dependency-notice`
entries cover the declared tree, including helpers hidden by upstream bundles
and optional plugins that may be tree-shaken. `type-or-build-only` and
`build-tool-only` entries do not imply redistribution of a runtime/tool binary.
Full copyright lines are in the linked original files, not replaced by a single
invented umbrella attribution. FastDom/boolbase's original MIT/ISC metadata is
preserved where npm supplied no standalone license file; no year is fabricated.

## npm packages and original notice files

| Package | Version | License used | Evidence scope | Original notice |
|---|---|---|---|---|
| @antfu/install-pkg | 2.1.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/antfu__install-pkg/2.1.0/LICENSE) |
| @babel/runtime | 7.29.10 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/babel__runtime/7.29.10/LICENSE) |
| @braintree/sanitize-url | 7.1.2 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/braintree__sanitize-url/7.1.2/LICENSE) |
| @chevrotain/cst-dts-gen | 13.2.0 | Apache-2.0 | audit-output | [Original](THIRD_PARTY_LICENSES/packages/chevrotain__cst-dts-gen/13.2.0/LICENSE.txt) |
| @chevrotain/gast | 13.2.0 | Apache-2.0 | upstream-prebundle-source-map, audit-output | [Original](THIRD_PARTY_LICENSES/packages/chevrotain__gast/13.2.0/LICENSE.txt) |
| @chevrotain/regexp-to-ast | 13.2.0 | Apache-2.0 | upstream-prebundle-source-map, audit-output | [Original](THIRD_PARTY_LICENSES/packages/chevrotain__regexp-to-ast/13.2.0/LICENSE.txt) |
| @chevrotain/types | 13.2.0 | Apache-2.0 | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/chevrotain__types/13.2.0/LICENSE.txt) |
| @chevrotain/utils | 13.2.0 | Apache-2.0 | upstream-prebundle-source-map, audit-output | [Original](THIRD_PARTY_LICENSES/packages/chevrotain__utils/13.2.0/LICENSE.txt) |
| @esbuild/darwin-arm64 | 0.25.12 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/esbuild/0.25.12/LICENSE.md) |
| @gera2ld/jsx-dom | 2.2.2 | ISC | embedded-banner | [Original](THIRD_PARTY_LICENSES/packages/gera2ld__jsx-dom/2.2.2/LICENSE) |
| @iconify/types | 2.0.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/iconify__types/2.0.0/license.txt) |
| @iconify/utils | 3.1.7 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/iconify__utils/3.1.7/license.txt) |
| @mermaid-js/parser | 2.0.1 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/mermaid-js__parser/2.0.1/LICENSE) |
| @types/d3 | 7.4.3 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3/7.4.3/LICENSE) |
| @types/d3-array | 3.2.2 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-array/3.2.2/LICENSE) |
| @types/d3-axis | 3.0.6 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-axis/3.0.6/LICENSE) |
| @types/d3-brush | 3.0.6 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-brush/3.0.6/LICENSE) |
| @types/d3-chord | 3.0.6 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-chord/3.0.6/LICENSE) |
| @types/d3-color | 3.1.3 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-color/3.1.3/LICENSE) |
| @types/d3-contour | 3.0.6 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-contour/3.0.6/LICENSE) |
| @types/d3-delaunay | 6.0.4 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-delaunay/6.0.4/LICENSE) |
| @types/d3-dispatch | 3.0.7 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-dispatch/3.0.7/LICENSE) |
| @types/d3-drag | 3.0.7 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-drag/3.0.7/LICENSE) |
| @types/d3-dsv | 3.0.7 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-dsv/3.0.7/LICENSE) |
| @types/d3-ease | 3.0.2 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-ease/3.0.2/LICENSE) |
| @types/d3-fetch | 3.0.7 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-fetch/3.0.7/LICENSE) |
| @types/d3-force | 3.0.10 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-force/3.0.10/LICENSE) |
| @types/d3-format | 3.0.4 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-format/3.0.4/LICENSE) |
| @types/d3-geo | 3.1.1 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-geo/3.1.1/LICENSE) |
| @types/d3-hierarchy | 3.1.7 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-hierarchy/3.1.7/LICENSE) |
| @types/d3-interpolate | 3.0.4 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-interpolate/3.0.4/LICENSE) |
| @types/d3-path | 3.1.1 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-path/3.1.1/LICENSE) |
| @types/d3-polygon | 3.0.2 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-polygon/3.0.2/LICENSE) |
| @types/d3-quadtree | 3.0.6 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-quadtree/3.0.6/LICENSE) |
| @types/d3-random | 3.0.4 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-random/3.0.4/LICENSE) |
| @types/d3-scale | 4.0.9 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-scale/4.0.9/LICENSE) |
| @types/d3-scale-chromatic | 3.1.0 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-scale-chromatic/3.1.0/LICENSE) |
| @types/d3-selection | 3.0.12 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-selection/3.0.12/LICENSE) |
| @types/d3-shape | 3.2.0 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-shape/3.2.0/LICENSE) |
| @types/d3-time | 3.0.4 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-time/3.0.4/LICENSE) |
| @types/d3-time-format | 4.0.3 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-time-format/4.0.3/LICENSE) |
| @types/d3-timer | 3.0.2 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-timer/3.0.2/LICENSE) |
| @types/d3-transition | 3.0.9 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-transition/3.0.9/LICENSE) |
| @types/d3-zoom | 3.0.9 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__d3-zoom/3.0.9/LICENSE) |
| @types/geojson | 7946.0.16 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__geojson/7946.0.16/LICENSE) |
| @types/trusted-types | 2.0.7 | MIT | type-or-build-only | [Original](THIRD_PARTY_LICENSES/packages/types__trusted-types/2.0.7/LICENSE) |
| @upsetjs/venn.js | 2.0.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/upsetjs__venn.js/2.0.0/LICENSE) |
| @vscode/markdown-it-katex | 1.1.2 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/vscode__markdown-it-katex/1.1.2/LICENSE) |
| argparse | 2.0.1 | Python-2.0 | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/argparse/2.0.1/LICENSE) |
| boolbase | 1.0.0 | ISC | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/boolbase/1.0.0/package.json) |
| cheerio | 1.0.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/cheerio/1.0.0/LICENSE) |
| cheerio-select | 2.1.0 | BSD-2-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/cheerio-select/2.1.0/LICENSE) |
| chevrotain | 13.2.0 | Apache-2.0 | upstream-prebundle-source-map, audit-output | [Original](THIRD_PARTY_LICENSES/packages/chevrotain/13.2.0/LICENSE.txt) |
| chevrotain-allstar | 0.5.0 | MIT | upstream-prebundle-source-map | [Original](THIRD_PARTY_LICENSES/packages/chevrotain-allstar/0.5.0/LICENSE) |
| commander | 15.0.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/commander/15.0.0/LICENSE) |
| commander | 7.2.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/commander/7.2.0/LICENSE) |
| commander | 8.3.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/commander/8.3.0/LICENSE) |
| cose-base | 1.0.3 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/cose-base/1.0.3/LICENSE) |
| cose-base | 2.2.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/cose-base/2.2.0/LICENSE) |
| css-select | 5.2.2 | BSD-2-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/css-select/5.2.2/LICENSE) |
| css-what | 6.2.2 | BSD-2-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/css-what/6.2.2/LICENSE) |
| cytoscape | 3.34.4 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/cytoscape/3.34.4/LICENSE) |
| cytoscape-cose-bilkent | 4.1.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/cytoscape-cose-bilkent/4.1.0/LICENSE) |
| cytoscape-fcose | 2.2.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/cytoscape-fcose/2.2.0/LICENSE) |
| d3 | 7.9.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3/7.9.0/LICENSE) |
| d3-array | 2.12.1 | BSD-3-Clause | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-array/2.12.1/LICENSE) |
| d3-array | 3.2.4 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-array/3.2.4/LICENSE) |
| d3-axis | 3.0.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-axis/3.0.0/LICENSE) |
| d3-brush | 3.0.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-brush/3.0.0/LICENSE) |
| d3-chord | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-chord/3.0.1/LICENSE) |
| d3-color | 3.1.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-color/3.1.0/LICENSE) |
| d3-contour | 4.0.2 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-contour/4.0.2/LICENSE) |
| d3-delaunay | 6.0.4 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-delaunay/6.0.4/LICENSE) |
| d3-dispatch | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-dispatch/3.0.1/LICENSE) |
| d3-drag | 3.0.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-drag/3.0.0/LICENSE) |
| d3-dsv | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-dsv/3.0.1/LICENSE) |
| d3-ease | 3.0.1 | BSD-3-Clause | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-ease/3.0.1/LICENSE) |
| d3-fetch | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-fetch/3.0.1/LICENSE) |
| d3-force | 3.0.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-force/3.0.0/LICENSE) |
| d3-format | 3.1.2 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-format/3.1.2/LICENSE) |
| d3-geo | 3.1.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-geo/3.1.1/LICENSE) |
| d3-hierarchy | 3.1.2 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-hierarchy/3.1.2/LICENSE) |
| d3-interpolate | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-interpolate/3.0.1/LICENSE) |
| d3-path | 1.0.9 | BSD-3-Clause | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-path/1.0.9/LICENSE) |
| d3-path | 3.1.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-path/3.1.0/LICENSE) |
| d3-polygon | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-polygon/3.0.1/LICENSE) |
| d3-quadtree | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-quadtree/3.0.1/LICENSE) |
| d3-random | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-random/3.0.1/LICENSE) |
| d3-sankey | 0.12.3 | BSD-3-Clause | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-sankey/0.12.3/LICENSE) |
| d3-scale | 4.0.2 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-scale/4.0.2/LICENSE) |
| d3-scale-chromatic | 3.1.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-scale-chromatic/3.1.0/LICENSE) |
| d3-selection | 3.0.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-selection/3.0.0/LICENSE) |
| d3-shape | 1.3.7 | BSD-3-Clause | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-shape/1.3.7/LICENSE) |
| d3-shape | 3.2.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-shape/3.2.0/LICENSE) |
| d3-time | 3.1.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-time/3.1.0/LICENSE) |
| d3-time-format | 4.1.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-time-format/4.1.0/LICENSE) |
| d3-timer | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-timer/3.0.1/LICENSE) |
| d3-transition | 3.0.1 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-transition/3.0.1/LICENSE) |
| d3-zoom | 3.0.0 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/d3-zoom/3.0.0/LICENSE) |
| dagre-d3-es | 7.0.14 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/dagre-d3-es/7.0.14/LICENSE.md) |
| dayjs | 1.11.23 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/dayjs/1.11.23/LICENSE) |
| delaunator | 5.1.0 | ISC | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/delaunator/5.1.0/LICENSE) |
| dom-serializer | 2.0.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/dom-serializer/2.0.0/LICENSE) |
| domelementtype | 2.3.0 | BSD-2-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/domelementtype/2.3.0/LICENSE) |
| domhandler | 5.0.3 | BSD-2-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/domhandler/5.0.3/LICENSE) |
| dompurify | 3.4.17 | Apache-2.0 | audit-output | [Original](THIRD_PARTY_LICENSES/packages/dompurify/3.4.17/LICENSE) |
| domutils | 3.2.2 | BSD-2-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/domutils/3.2.2/LICENSE) |
| elkjs | 0.9.3 | EPL-2.0 | audit-output | [Original](THIRD_PARTY_LICENSES/packages/elkjs/0.9.3/LICENSE.md) |
| encoding-sniffer | 0.2.1 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/encoding-sniffer/0.2.1/LICENSE) |
| entities | 4.5.0 | BSD-2-Clause | audit-output | [Original](THIRD_PARTY_LICENSES/packages/entities/4.5.0/LICENSE) |
| entities | 6.0.1 | BSD-2-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/entities/6.0.1/LICENSE) |
| es-toolkit | 1.52.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/es-toolkit/1.52.0/LICENSE) |
| esbuild | 0.25.12 | MIT | build-tool-only | [Original](THIRD_PARTY_LICENSES/packages/esbuild/0.25.12/LICENSE.md) |
| fastdom | 1.0.12 | MIT | upstream-prebundle-source-map | [Original](THIRD_PARTY_LICENSES/packages/fastdom/1.0.12/package.json) |
| hachure-fill | 0.5.2 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/hachure-fill/0.5.2/LICENSE) |
| highlight.js | 11.12.0 | BSD-3-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/highlight.js/11.12.0/LICENSE) |
| htmlparser2 | 9.1.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/htmlparser2/9.1.0/LICENSE) |
| iconv-lite | 0.6.3 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/iconv-lite/0.6.3/LICENSE) |
| import-meta-resolve | 4.2.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/import-meta-resolve/4.2.0/license) |
| internmap | 1.0.1 | ISC | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/internmap/1.0.1/LICENSE) |
| internmap | 2.0.3 | ISC | audit-output | [Original](THIRD_PARTY_LICENSES/packages/internmap/2.0.3/LICENSE) |
| js-yaml | 4.3.0 | MIT | upstream-prebundle-source-map | [Original](THIRD_PARTY_LICENSES/packages/js-yaml/4.3.0/LICENSE) |
| katex | 0.16.27 | MIT | standalone-asset | [Original](THIRD_PARTY_LICENSES/packages/katex/0.16.27/LICENSE) |
| katex | 0.16.47 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/katex/0.16.47/LICENSE) |
| katex | 0.18.10 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/katex/0.18.10/LICENSE) |
| khroma | 2.1.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/khroma/2.1.0/license) |
| langium | 4.4.0 | MIT | upstream-prebundle-source-map | [Original](THIRD_PARTY_LICENSES/packages/langium/4.4.0/LICENSE) |
| layout-base | 1.0.2 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/layout-base/1.0.2/LICENSE) |
| layout-base | 2.0.1 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/layout-base/2.0.1/LICENSE) |
| linkify-it | 5.0.2 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/linkify-it/5.0.2/LICENSE) |
| lodash-es | 4.18.1 | MIT | audit-output, upstream-prebundle-source-map | [Original](THIRD_PARTY_LICENSES/packages/lodash-es/4.18.1/LICENSE) |
| markdown-it | 14.3.3 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/markdown-it/14.3.3/LICENSE) |
| markdown-it-ins | 4.0.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/markdown-it-ins/4.0.0/LICENSE) |
| markdown-it-mark | 4.0.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/markdown-it-mark/4.0.0/LICENSE) |
| markdown-it-sub | 2.0.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/markdown-it-sub/2.0.0/LICENSE) |
| markdown-it-sup | 2.0.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/markdown-it-sup/2.0.0/LICENSE) |
| marked | 16.4.2 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/marked/16.4.2/LICENSE.md) |
| markmap-common | 0.18.9 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/markmap-common/0.18.9/LICENSE) |
| markmap-html-parser | 0.18.11 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/markmap-html-parser/0.18.11/LICENSE) |
| markmap-lib | 0.18.12 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/markmap-lib/0.18.12/LICENSE) |
| markmap-view | 0.18.12 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/markmap-view/0.18.12/LICENSE) |
| mdurl | 2.1.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/mdurl/2.1.0/LICENSE) |
| mermaid | 12.2.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/mermaid/12.2.0/LICENSE) |
| npm2url | 0.2.4 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/npm2url/0.2.4/LICENSE) |
| nth-check | 2.1.1 | BSD-2-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/nth-check/2.1.1/LICENSE) |
| package-manager-detector | 1.9.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/package-manager-detector/1.9.0/LICENSE) |
| parse5 | 7.3.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/parse5/7.3.0/LICENSE) |
| parse5-htmlparser2-tree-adapter | 7.1.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/parse5-htmlparser2-tree-adapter/7.1.0/LICENSE) |
| parse5-parser-stream | 7.1.2 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/parse5-parser-stream/7.1.2/LICENSE) |
| path-data-parser | 0.1.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/path-data-parser/0.1.0/LICENSE) |
| points-on-curve | 0.2.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/points-on-curve/0.2.0/LICENSE) |
| points-on-path | 0.2.1 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/points-on-path/0.2.1/LICENSE) |
| prismjs | 1.30.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/prismjs/1.30.0/LICENSE) |
| punycode.js | 2.3.1 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/punycode.js/2.3.1/LICENSE-MIT.txt) |
| robust-predicates | 3.0.3 | Unlicense | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/robust-predicates/3.0.3/LICENSE) |
| roughjs | 4.6.6 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/roughjs/4.6.6/LICENSE) |
| rw | 1.3.3 | BSD-3-Clause | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/rw/1.3.3/LICENSE) |
| safer-buffer | 2.1.2 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/safer-buffer/2.1.2/LICENSE) |
| stylis | 4.4.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/stylis/4.4.0/LICENSE) |
| tinyexec | 1.3.1 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/tinyexec/1.3.1/LICENSE) |
| ts-dedent | 2.3.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/ts-dedent/2.3.0/LICENSE) |
| uc.micro | 2.1.0 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/uc.micro/2.1.0/LICENSE.txt) |
| undici | 6.29.1 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/undici/6.29.1/LICENSE) |
| uuid | 14.0.3 | MIT | audit-output | [Original](THIRD_PARTY_LICENSES/packages/uuid/14.0.3/LICENSE.md) |
| vscode-jsonrpc | 9.0.3 | MIT | upstream-prebundle-source-map, embedded-module-path | [Original](THIRD_PARTY_LICENSES/packages/vscode-jsonrpc/9.0.3/License.txt) |
| vscode-languageserver-protocol | 3.18.4 | MIT | upstream-prebundle-source-map, embedded-module-path | [Original](THIRD_PARTY_LICENSES/packages/vscode-languageserver-protocol/3.18.4/License.txt) |
| vscode-languageserver-textdocument | 1.0.15 | MIT | upstream-prebundle-source-map | [Original](THIRD_PARTY_LICENSES/packages/vscode-languageserver-textdocument/1.0.15/License.txt) |
| vscode-languageserver-types | 3.18.4 | MIT | upstream-prebundle-source-map, embedded-module-path | [Original](THIRD_PARTY_LICENSES/packages/vscode-languageserver-types/3.18.4/License.txt) |
| whatwg-encoding | 3.1.1 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/whatwg-encoding/3.1.1/LICENSE.txt) |
| whatwg-mimetype | 4.0.0 | MIT | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/whatwg-mimetype/4.0.0/LICENSE.txt) |
| yaml | 2.9.1 | ISC | conservative-dependency-notice | [Original](THIRD_PARTY_LICENSES/packages/yaml/2.9.1/LICENSE) |

## Embedded contributions

- **regenerator-runtime helper** — MIT; DOMPurify 3.4.17 prebuilt module. The embedded helper does not separately declare its version; supplemental permission text comes from upstream regenerator-runtime 0.14.1, not a claim of the helper version.
- **Thenable/Promise 1.1.1, jQuery-derived events, Bezier and Runge-Kutta helpers** — MIT; Cytoscape 3.34.4 prebuilt module. Original Ralf S. Engelschall, Gaetan Renaudeau, Koen Bok and jQuery attribution banners are retained.

## ELK Java source/build dependencies (conservative coverage)

| Component | Version | License | Source and notices |
|---|---|---|---|
| com.google.guava:guava | 31.1-jre | Apache-2.0 | [Source](https://repo.maven.apache.org/maven2/com/google/guava/guava/31.1-jre/guava-31.1-jre-sources.jar), [headers](THIRD_PARTY_LICENSES/maven/com.google.guava/guava/31.1-jre/SOURCE_COPYRIGHT_HEADERS.txt) |
| com.google.guava:guava-gwt | 31.1-jre | Apache-2.0 | [Source](https://repo.maven.apache.org/maven2/com/google/guava/guava-gwt/31.1-jre/guava-gwt-31.1-jre-sources.jar), [headers](THIRD_PARTY_LICENSES/maven/com.google.guava/guava-gwt/31.1-jre/SOURCE_COPYRIGHT_HEADERS.txt) |
| org.gwtproject:gwt-user | 2.10.0 | Apache-2.0 | [Source](https://repo.maven.apache.org/maven2/org/gwtproject/gwt-user/2.10.0/gwt-user-2.10.0-sources.jar), [headers](THIRD_PARTY_LICENSES/maven/org.gwtproject/gwt-user/2.10.0/SOURCE_COPYRIGHT_HEADERS.txt) |
| org.gwtproject:gwt-dev | 2.10.0 | Apache-2.0 | [Source](https://repo.maven.apache.org/maven2/org/gwtproject/gwt-dev/2.10.0/gwt-dev-2.10.0-sources.jar), [headers](THIRD_PARTY_LICENSES/maven/org.gwtproject/gwt-dev/2.10.0/SOURCE_COPYRIGHT_HEADERS.txt) |
| com.genmymodel.emf.gwt:emf-common | 2.12.4 | EPL-1.0 | [Source](https://repo.maven.apache.org/maven2/com/genmymodel/emf/gwt/emf-common/2.12.4/emf-common-2.12.4-sources.jar), [headers](THIRD_PARTY_LICENSES/maven/com.genmymodel.emf.gwt/emf-common/2.12.4/SOURCE_COPYRIGHT_HEADERS.txt) |
| com.genmymodel.emf.gwt:emf-ecore | 2.12.4 | EPL-1.0 | [Source](https://repo.maven.apache.org/maven2/com/genmymodel/emf/gwt/emf-ecore/2.12.4/emf-ecore-2.12.4-sources.jar), [headers](THIRD_PARTY_LICENSES/maven/com.genmymodel.emf.gwt/emf-ecore/2.12.4/SOURCE_COPYRIGHT_HEADERS.txt) |
| org.eclipse.xtend:org.eclipse.xtend.lib | 2.28.0 | EPL-2.0 | [Source](https://repo.maven.apache.org/maven2/org/eclipse/xtend/org.eclipse.xtend.lib/2.28.0/org.eclipse.xtend.lib-2.28.0-sources.jar), [headers](THIRD_PARTY_LICENSES/maven/org.eclipse.xtend/org.eclipse.xtend.lib/2.28.0/about_org.eclipse.xtend.lib.html) |
| org.eclipse.xtext:org.eclipse.xtext.xbase.lib | 2.28.0 | EPL-2.0 | [Source](https://repo.maven.apache.org/maven2/org/eclipse/xtext/org.eclipse.xtext.xbase.lib/2.28.0/org.eclipse.xtext.xbase.lib-2.28.0-sources.jar), [headers](THIRD_PARTY_LICENSES/maven/org.eclipse.xtext/org.eclipse.xtext.xbase.lib/2.28.0/about_org.eclipse.xtext.xbase.lib.html) |

## Verification scope and limitations

- An original producer lockfile/build receipt is unavailable. The checked-in audit reconstruction passes scope-aware AST alpha equivalence for all 4233 library statements; the final local bridge is excluded and neither deployed JS asset is replaced.
- Source-map and declared-closure entries are conservative notice coverage. A package appearing in that closure is not proof that every file/version is emitted; type packages and esbuild are not app runtime payloads.
- ELK Java source provenance follows the upstream elkjs 0.9.3 release declaration (ELK 0.9.1 plus PR 955), build.gradle and checksum-verified Maven sources. The original upstream GWT compilation is not independently reproduced.
- FastDom and boolbase npm archives omit standalone license files; original SPDX declarations and authors are preserved with standard permission text, without inventing an upstream copyright year.
- Inventory, original notice collection and source availability verification are engineering evidence, not a legal warranty or a native GUI acceptance sign-off.
