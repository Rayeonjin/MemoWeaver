#!/bin/bash
# Reuse the official Mermaid+Markmap IIFE already included in the user's
# successful v0.9.6 build. Does not touch the installed app or personal notes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
OUT="$ROOT/WorkOSMac/Resources/official-diagrams.js"
usage() {
  cat <<'HELP'
Usage: ./carry-official-diagrams.sh [OLD_APP_OR_JS_FILE]

Examples:
  ./carry-official-diagrams.sh "$HOME/Downloads/MemoryHome_Mac_v0.9.6_CLT/build/Release/기억의 집.app"
  ./carry-official-diagrams.sh "$HOME/Applications/기억의 집.app"
  ./carry-official-diagrams.sh "/Applications/기억의 집.app"

Without an argument, looks for previously installed v0.9.6 app bundles
in standard user locations. This copies only the local official-diagrams.js.
The v0.9.7 preview corrects the old engine's width:100% at runtime.
HELP
}
case "${1:-}" in --help|-h) usage; exit 0;; esac
[[ $# -le 1 ]] || { usage >&2; exit 1; }
# The distributed bundle now contains the official renderer.  An explicit
# source argument remains available for manually updating it.
if [[ $# -eq 0 && -s "$OUT" ]] && grep -Fq 'MemoryHomeOfficialDiagrams' "$OUT"; then
  if command -v node >/dev/null 2>&1; then node --check "$OUT"; fi
  echo '[MemoryHome] Official Mermaid/Markmap JS is already bundled; skipping carry.'
  exit 0
fi
candidates=()
if [[ $# -eq 1 ]]; then
  candidates+=("$1")
else
  candidates+=(
    "$HOME/Downloads/MemoryHome_Mac_v0.9.6_CLT/build/Release/기억의 집.app"
    "$HOME/Applications/기억의 집.app"
    "/Applications/기억의 집.app"
    "$HOME/Downloads/기억의 집.app"
  )
fi
selected=''
for candidate in "${candidates[@]}"; do
  if [[ -d "$candidate" ]]; then
    candidate="$candidate/Contents/Resources/official-diagrams.js"
  fi
  if [[ -f "$candidate" && -s "$candidate" ]]; then selected="$candidate"; break; fi
done
if [[ -z "$selected" ]]; then
  echo '[MemoryHome] Cannot find the previous app official-diagrams.js.' >&2
  echo '[MemoryHome] Pass the old v0.9.6 built .app or the 5.3MB JS file as the first argument.' >&2
  echo '[MemoryHome] Or prepare a fresh bundle with ./prepare-official-renderers.sh' >&2
  exit 1
fi
bytes="$(wc -c < "$selected" | tr -d ' ')"
[[ "$bytes" -ge 1000000 ]] || { echo "[MemoryHome] Rejecting incomplete JS file ($bytes bytes)." >&2; exit 1; }
grep -Fq 'MemoryHomeOfficialDiagrams' "$selected" || {
  echo '[MemoryHome] Existing JS has no MemoryHomeOfficialDiagrams bridge.' >&2; exit 1;
}
mkdir -p "$(dirname "$OUT")"
TMP="$OUT.tmp.$$.js"
trap 'rm -f "$TMP"' EXIT
cp "$selected" "$TMP"
if command -v node >/dev/null 2>&1; then node --check "$TMP"; fi
mv -f "$TMP" "$OUT"
echo "[MemoryHome] Official diagrams reused: $OUT ($bytes bytes)."
echo '[MemoryHome] Next: ./test-official-diagrams.sh --require-bundle && ./build.sh'
