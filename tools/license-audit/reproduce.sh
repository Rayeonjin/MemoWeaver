#!/bin/bash
# Optional networked audit reproduction; does not modify installed JS assets.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-license-reproduce.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/runtime" "$TMP/parser"
cp "$ROOT"/Vendor/official-diagrams/audit-reconstruction/{package.json,package-lock.json,entry.js} "$TMP/runtime/"
cp "$ROOT"/tools/license-audit/{package.json,package-lock.json} "$TMP/parser/"
(cd "$TMP/runtime" && npm ci --ignore-scripts --no-audit --no-fund)
(cd "$TMP/parser" && npm ci --ignore-scripts --no-audit --no-fund)
(cd "$TMP/runtime" && ./node_modules/.bin/esbuild entry.js \
 --bundle --format=iife --platform=browser --target=safari17.4 --minify \
 --legal-comments=inline --metafile=metafile.json --outfile=candidate.js)
NODE_PATH="$TMP/parser/node_modules" node "$ROOT/tools/license-audit/compare-bundles.cjs" \
 "$ROOT/WorkOSMac/Resources/official-diagrams.js" "$TMP/runtime/candidate.js"
NODE_PATH="$TMP/parser/node_modules" python3 "$ROOT/Tests/LicenseAstComparisonSmoke.py"
echo 'PASS: locked reconstruction matches all retained library statements; only local bridge excluded'
