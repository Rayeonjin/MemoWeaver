#!/bin/bash
# ONE-TIME developer preparation (requires internet/Node >=22). The installed
# app itself requires only macOS 14+ and Apple Command Line Tools for builds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SRC="$ROOT/Vendor/official-diagrams"
OUT="$ROOT/WorkOSMac/Resources/official-diagrams.js"
fail() { echo "[MemoryHome] ERROR: $*" >&2; exit 1; }
command -v node >/dev/null 2>&1 || fail "Node.js 22+ is required ONE TIME to prepare the official engine (not to run the app)."
command -v npm >/dev/null 2>&1 || fail "npm was not found."
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[[ "$NODE_MAJOR" =~ ^[0-9]+$ && "$NODE_MAJOR" -ge 22 ]] || fail "Node.js 22+ is required for Mermaid 12.2.0."
[[ -f "$SRC/package.json" && -f "$SRC/entry.js" ]] || fail "Missing Vendor/official-diagrams sources."
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/memoryhome-diagrams.XXXXXXXX")" || exit 1
trap 'rm -rf -- "$TEMP"' EXIT
cp "$SRC/package.json" "$SRC/entry.js" "$TEMP/"
printf '[MemoryHome] Installing pinned upstream packages in a temporary build folder...\n'
(cd "$TEMP" && npm install --no-fund --no-audit --no-save --ignore-scripts=false)
printf '[MemoryHome] Bundling offline Mermaid 12.2.0 and Markmap 0.18.12...\n'
"$TEMP/node_modules/.bin/esbuild" "$TEMP/entry.js" \
  --bundle --format=iife --platform=browser --target=safari17.4 --minify \
  --legal-comments=inline --outfile="$TEMP/official-diagrams.js"
[[ -s "$TEMP/official-diagrams.js" ]] || fail "Bundler produced no JavaScript."
node --check "$TEMP/official-diagrams.js" || fail "Bundled JavaScript syntax invalid."
grep -Fq MemoryHomeOfficialDiagrams "$TEMP/official-diagrams.js" || fail "Bridge export missing."
# Avoid partial file replacement; only publish after every check succeeds.
cp "$TEMP/official-diagrams.js" "$OUT.tmp.$$"
mv "$OUT.tmp.$$" "$OUT"
printf '[MemoryHome] Prepared %s (%s bytes).\n' "$OUT" "$(wc -c < "$OUT" | tr -d ' ')"
printf '[MemoryHome] The macOS app will now bundle this locally at ./build.sh. No runtime downloads.\n'
