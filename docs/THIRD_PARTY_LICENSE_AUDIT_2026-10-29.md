# Third-party license and copyright audit

Audit started 2026-10-29, based on MemoWeaver v0.9.64 / Build 97 and the retained
source assets. This is an engineering inventory and original-notice collection,
not a legal warranty, a notarized binary release, or manual GUI acceptance.

## Result

- Both runtime JavaScript assets remain byte-for-byte unchanged.
- 171 npm package/version records are documented. This is intentionally broader
  than the emitted runtime: it includes direct output evidence, upstream
  prebundle maps, embedded banners/module paths, conservative declared helpers,
  optional plugins, types and build tools. It is not a claim of 171 runtime libs.
- Eight ELK Java source/build dependency records preserve source locations,
  checksum evidence and original copyright headers, including EPL-1.0 EMF.
- 204 original legal/author/source-header files are referenced in the aggregate.
  Additional POM/source evidence and integrity records are preserved separately.
- The app ships the original legal directory, project notices, and source-access
  information. Standalone HTML embeds the complete legal/source text as
  non-executable JSON, without making live previews carry that extra payload.

## Important license corrections

| Component | Verified identity/evidence | Terms and action |
|---|---|---|
| Mermaid | 12.2.0 manifest, official archive and reconstruction | Preserve original MIT license/copyright |
| Markmap family | lib/view 0.18.12; common/parser separately versioned | Preserve each package's MIT original text |
| KaTeX | 0.16.27 standalone embedded version, 0.18.10 in Mermaid output | Preserve both MIT copies; no separate font assets shipped |
| DOMPurify | 3.4.17 original banner and matching reconstruction module | Select Apache-2.0 from the dual license; retain original full dual text |
| ELK / elkjs | elkjs 0.9.3, exact upstream source tag and release notes | EPL-2.0 text and public source-access statement included |
| EMF for GWT | emf-common/ecore 2.12.4 in elkjs build.gradle and source archives | EPL-1.0 text, exact IBM/Ed Merks/etc. headers and source links included |
| GWT, Guava, Xtext/Xtend | Upstream Java source/build inputs | Original headers, inherited POMs and root copying/about files included; conservative coverage |
| D3 family | Output/source-map/package evidence | ISC/BSD/MIT varies by package/version; do not blanket-label D3 as MIT |
| Lodash / Underscore | Lodash-es 4.18.1 banner and original license | Preserve OpenJS and Underscore attribution |
| regenerator helper | Present inside DOMPurify's prebuilt module | Preserve Facebook banner and MIT text; separate helper version is not declared |
| Promise/events/animation helpers | Present inside Cytoscape's prebuilt module | Preserve Ralf S. Engelschall, jQuery, Gaetan Renaudeau and Koen Bok banners |
| FastDom / boolbase | Exact npm MIT/ISC declarations | Packages omit standalone license files; preserve metadata/authors/readme plus permission text; invent no copyright year |

The original inline banners are copied exactly under
`THIRD_PARTY_LICENSES/embedded/`. Original holders and years in package files
are preserved, rather than replaced with Rayeonjin or a generic project credit.
Project-owned code remains Apache-2.0 with Copyright (c) 2026 Rayeonjin.

## Retained runtime identity

- `WorkOSMac/Resources/official-diagrams.js`:
  `9bbaa30a1961ce26626502392bc5f63280ec5822cfa45b7a9702092c96d1eff5`
- `WorkOSMac/Resources/katex-mathml.js`:
  `8852a8b8326f1d3e85412a7cd16de09f10186c1aefd70434607b001bbe443edc`

A fresh `npm ci --ignore-scripts` reconstruction uses the pinned top-level
versions and explicitly constrains es-toolkit to 1.52.0. Resolving its later
1.53.0 produced real code differences, so that later version was not silently
assigned to the retained asset.

The checked-in scope-aware AST comparator verifies **all 4,233 library
statements** against that locked reconstruction. It normalizes only bound
identifier names and parser positions/comments, retaining lexical binding
identity, property names, literals, operators and statement order. Tests prove
that changed literals, properties and lexical references are rejected.

Only the last local MemoWeaver bridge IIFE is excluded. Its natural-width
behavior differs from the retained bridge; the reconstruction is never copied
into app resources. The original producer's lockfile/build receipt is still
unavailable and is not falsely claimed to have been recovered.

The standalone KaTeX asset's declared version is recorded separately. It was
not replaced by the investigated upstream/minifier output.

## Source access and copyright evidence

Git attributes retain upstream legal documents byte-for-byte, including original
line endings/whitespace; integrity checks replace formatting those originals.

Every collected npm archive is checked against its official registry integrity
digest. Each notice file has a SHA-256. Maven source archives are checked against
the repository checksum and recorded with SHA-256. `FILES.sha256` covers the
entire shipped legal directory, and the export aggregate includes current
project LICENSE/NOTICE/COPYRIGHT as well as upstream legal texts.

For EPL components, `THIRD_PARTY_LICENSES/SOURCE_AVAILABILITY.md` provides public
source locations in the same customary electronic medium as the distribution:

- [elkjs 0.9.3 exact release source](https://github.com/kieler/elkjs/tree/a8304cf79fde75bc2ab1a89d28320f53f8637436).
- [Upstream release declaration](https://github.com/kieler/elkjs/releases/tag/0.9.3): ELK 0.9.1 plus PR 955.
- [ELK 0.9.1 base source](https://github.com/eclipse-elk/elk/tree/62d5909f96fad541bc101ad52dabaece6b7eab7e).
- [Additional ELK patch](https://github.com/eclipse-elk/elk/pull/955).
- Exact, checksum-verified Maven source archive URLs for EMF GWT and other
  Java inputs are in `maven-manifest.json` and the source-availability document.

The original upstream GWT compilation and exact historical Java build receipt
are not independently reproduced. The Java component provenance follows the
original maintainer's release declaration, source tag and build.gradle.

## Evidence classes and limits

1. `audit-output`, standalone-asset, original banners/module paths and
   upstream-prebundle maps are recorded individually. Source-map/declared-closure
   coverage is conservative; not every package/file in that set is emitted.
2. Type packages, esbuild and its optional platform binary are development
   inputs, not runtime payloads redistributed inside MemoWeaver.
3. FastDom and boolbase supplied no standalone license file in their published
   archives. Their actual SPDX declarations and authors/readme are preserved
   with standard permission text. No missing copyright year is fabricated.
4. An embedded regenerator helper supplies no separate version. Its original
   banner is authoritative evidence; supplemental text from upstream runtime
   0.14.1 is not presented as proof that the embedded helper has that version.
5. System macOS frameworks/SQLite are linked, not bundled; Ollama executables
   and AI model weights are not distributed. Icon-artwork ownership and native
   GUI acceptance are separate from this external-library audit.
6. EPL component terms and source access are retained separately from project
   Apache terms. The project license does not overwrite third-party rights.

## Verification

Completed before the final application build:

- Official npm archive integrity checks and original legal file collection.
- Maven source checksums, parent-license declarations, and copyright headers.
- A fresh locked npm ci reconstruction and all 4,233 library-statement matches.
- Negative AST tests: changed literals, properties and references rejected.
- Offline asset/notice hashes and legal-directory completeness.
- Standalone HTML: exact Unicode/legal/source text roundtrip and closing-tag
  injection protection in non-executable JSON.
- Public-source preflight: no excluded user data or credential patterns.

Final verification: `./install-v0.9.64.sh --verify` PASSED all 13 suites, then
compiled/linked the native arm64 macOS app and verified its local ad-hoc signature.
`python3 tools/verify-third-party-licenses.py --app build/Release/MemoWeaver.app`
PASSED exact comparison of every legal resource and both unchanged JS assets.
A separate strict codesign verification also PASSED. The full local log is
`build/Logs/third-party-license-verify.log` (generated, excluded from Git).

Completed suites:

- `test-third-party-licenses.sh`
- `test-review-stability.sh`
- `test-v0.9.64-schedule.sh`
- `test-v0.9.64-pointer-symbols.sh`
- `test-v0.9.64-toolkit.sh`
- `test-v0.9.64-live-preview.sh`
- `test-v0.9.64-optimization.sh`
- `test-v0.9.60-brand-data.sh`
- `test-v0.9.59-ratio-cycle.sh`
- `test-v0.9.60-editor-hotpath.sh`
- `test-side-preview.sh`
- `test-v0.9.51-notebooks.sh`
- `test-v0.9.27-pinned-paste-ui.sh`

Human GUI, notifications, and real Korean IME were not run for this notice-only
packaging/export change. No app installation or live database access occurs.

## Reproduction and rollback

- `python3 tools/verify-third-party-licenses.py`: offline audit integrity gate.
- `./test-third-party-licenses.sh`: offline integrity plus Swift export test.
- `./tools/license-audit/reproduce.sh`: optional networked investigation-only
  rebuild; npm lifecycle scripts are disabled and installed assets are untouched.
- `./install-v0.9.64.sh --verify`: all current QA suites and native app build.
- `python3 tools/verify-third-party-licenses.py --app build/Release/MemoWeaver.app`:
  compare every packaged original legal file and retained runtime hash.

Work is isolated on `weekly/2026-10-29-dependency-licenses`; version/build remain
unchanged because this is not a new app release. Rollback is the preceding
copyright-notices commit. No data migration or schema change is involved.
