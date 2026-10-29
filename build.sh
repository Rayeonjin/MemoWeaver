#!/bin/bash
# MemoWeaver: native macOS app build using Apple Command Line Tools (CLT) only.
# Requires no Xcode.app, Xcode project, xcodebuild, web server, or third-party build tool.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE_DIR="$ROOT/WorkOSMac"
BUILD_DIR="$ROOT/build"
OUTPUT_DIR="$BUILD_DIR/Release"
LOG_DIR="$BUILD_DIR/Logs"
LOG_FILE="$LOG_DIR/swiftc-release.log"
OUTPUT_APP="$OUTPUT_DIR/MemoWeaver.app"
CLT_DIR="${MEMOWEAVER_CLT_DIR:-${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}}"

fail() { printf '\n[MemoWeaver] ERROR: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage: ./build.sh

Build MemoWeaver.app with Apple Command Line Tools swiftc only.
No Xcode installation or xcodebuild is needed.

Output: build/Release/MemoWeaver.app
Errors: build/Logs/swiftc-release.log

Environment variable MEMOWEAVER_CLT_DIR (legacy: WORKOS_CLT_DIR) overrides the default
/Library/Developer/CommandLineTools location.
HELP
}

case "${1:-}" in
  --help|-h) usage; exit 0 ;;
  "") ;;
  *) fail "Unknown argument: $1" ;;
esac
[[ $# -le 1 ]] || fail "Too many arguments. Run ./build.sh --help"

[[ "$(uname -s)" == Darwin ]] || fail "Build must run on macOS."
[[ -d "$SOURCE_DIR" && -f "$SOURCE_DIR/WorkOSApp.swift" && -f "$SOURCE_DIR/Info.plist" ]] || fail "Source files missing; extract the full ZIP."
[[ -d "$CLT_DIR" ]] || fail "Apple Command Line Tools directory not found at $CLT_DIR."
command -v xcrun >/dev/null 2>&1 || fail "xcrun is missing. Install Apple's Command Line Tools (xcode-select --install)."
command -v codesign >/dev/null 2>&1 || fail "macOS codesign tool is missing."
command -v plutil >/dev/null 2>&1 || fail "macOS plutil tool is missing."

# Pin to the standalone Command Line Tools. Ignore any active full-Xcode selection.
export DEVELOPER_DIR="$CLT_DIR"
SWIFTC="$(xcrun --sdk macosx --find swiftc 2>/dev/null)" || fail "CLT swiftc unavailable. Verify Command Line Tools installation."
SDK="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)" || fail "CLT macOS SDK unavailable."
[[ -x "$SWIFTC" && -d "$SDK" ]] || fail "Swift compiler or macOS SDK is missing."

ARCH="$(uname -m)"
case "$ARCH" in
  arm64|x86_64) ;;
  *) fail "Unsupported Mac architecture: $ARCH" ;;
esac

# The app uses SwiftUI APIs introduced in macOS 14.0.
if command -v sw_vers >/dev/null 2>&1; then
  MACOS_VERSION="$(sw_vers -productVersion)"
  MACOS_MAJOR="${MACOS_VERSION%%.*}"
  case "$MACOS_MAJOR" in
    ''|*[!0-9]*) fail "Cannot identify macOS version: $MACOS_VERSION" ;;
  esac
  [[ "$MACOS_MAJOR" -ge 14 ]] || fail "MemoWeaver requires macOS 14 or later (detected $MACOS_VERSION)."
fi

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR" "$LOG_DIR"
# .pcm caches embed the absolute directory where they were created. If the
# extracted source folder is moved (for example Downloads -> .Trash), reusing
# the old cache produces a misleading "missing required module SwiftShims".
CACHE_DIR="$BUILD_DIR/ModuleCache"
CACHE_ORIGIN="$BUILD_DIR/.module-cache-origin"
if [[ -d "$CACHE_DIR" ]]; then
  OLD_CACHE_ORIGIN="$(cat "$CACHE_ORIGIN" 2>/dev/null || true)"
  if [[ "$OLD_CACHE_ORIGIN" != "$CACHE_DIR" ]]; then
    printf '[MemoWeaver] Clearing moved or untracked Swift module cache.\n'
    rm -rf -- "$CACHE_DIR"
  fi
fi
mkdir -p "$CACHE_DIR"
printf '%s\n' "$CACHE_DIR" > "$CACHE_ORIGIN"
SOURCES=("$SOURCE_DIR"/*.swift)
[[ ${#SOURCES[@]} -gt 0 && -f "${SOURCES[0]}" ]] || fail "Swift sources missing."

STAGE_DIR="$(mktemp -d "$BUILD_DIR/.memoweaver-build.XXXXXXXX")" || fail "Cannot create temporary build directory."
cleanup() { if [[ -d "${STAGE_DIR:-/dev/null}" ]]; then rm -rf -- "$STAGE_DIR"; fi; }
trap cleanup EXIT
STAGED_APP="$STAGE_DIR/MemoWeaver.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp "$SOURCE_DIR/Info.plist" "$STAGED_APP/Contents/Info.plist"
# Local math typesetter (JavaScript only, MathML output). No fonts, network,
# or package manager are needed at runtime.
[[ -s "$SOURCE_DIR/Resources/katex-mathml.js" ]] || fail "KaTeX local renderer missing; extract the whole ZIP."
cp "$SOURCE_DIR/Resources/katex-mathml.js" "$STAGED_APP/Contents/Resources/katex-mathml.js"
# An optional, prebuilt, SINGLE-file official Mermaid + Markmap bundle.
# Prepared once on a developer machine. Never downloaded by the app.
OFFICIAL_JS="$SOURCE_DIR/Resources/official-diagrams.js"
if [[ -s "$OFFICIAL_JS" ]] && grep -Fq 'MemoryHomeOfficialDiagrams' "$OFFICIAL_JS"; then
  cp "$OFFICIAL_JS" "$STAGED_APP/Contents/Resources/official-diagrams.js"
  echo '[MemoWeaver] Local official Mermaid + Markmap engines bundled.'
else
  echo '[MemoWeaver] Official diagram bundle unavailable; original offline SVG fallback enabled.'
  echo '[MemoWeaver] Optional ONE-TIME setup: ./prepare-official-renderers.sh'
fi
# Distribute the notices with the app, not only with the source archive.
# This file is still an INCOMPLETE transitive dependency audit; do not label
# the binary redistribution-ready before the full license inventory is done.
[[ -s "$ROOT/THIRD_PARTY_NOTICES.md" ]] || fail "Third-party notices missing."
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$STAGED_APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
# Carry the project's actual license and attribution into every compiled app.
# Source permissions and brand permissions remain separate documents.
for legal_file in LICENSE NOTICE COPYRIGHT.md TRADEMARKS.md BRAND_ASSETS.md; do
  [[ -s "$ROOT/$legal_file" ]] || fail "Required legal notice missing: $legal_file"
  cp "$ROOT/$legal_file" "$STAGED_APP/Contents/Resources/$legal_file"
done
# Build the user-selected mosaic memory icon with built-in macOS tools.
# This runs only during compilation; the installed app does not need sips/iconutil.
ICON_PNG="$SOURCE_DIR/Resources/MemoWeaverIcon.png"
[[ -s "$ICON_PNG" ]] || fail "MemoWeaver icon image missing; extract the whole ZIP."
command -v sips >/dev/null 2>&1 || fail "macOS sips utility is missing."
command -v iconutil >/dev/null 2>&1 || fail "macOS iconutil utility is missing."
ICONSET="$STAGE_DIR/MemoWeaver.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null || fail "Icon generation failed at ${size}px."
  double=$((size * 2))
  sips -s format png -z "$double" "$double" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null || fail "Retina icon generation failed at ${double}px."
done
iconutil -c icns "$ICONSET" -o "$STAGED_APP/Contents/Resources/MemoWeaver.icns" || fail "Cannot compile macOS app icon."
[[ -s "$STAGED_APP/Contents/Resources/MemoWeaver.icns" ]] || fail "Generated app icon is empty."
printf 'APPL????' > "$STAGED_APP/Contents/PkgInfo"
plutil -lint "$STAGED_APP/Contents/Info.plist" >/dev/null || fail "Invalid Info.plist."
if grep -F '$(' "$STAGED_APP/Contents/Info.plist" >/dev/null; then
  fail "Info.plist still contains an unresolved build placeholder."
fi

printf '[MemoWeaver] Building with Apple Command Line Tools (no Xcode)\n'
printf '[MemoWeaver] Swift compiler: %s\n' "$SWIFTC"
printf '[MemoWeaver] macOS SDK: %s\n' "$SDK"
printf '[MemoWeaver] Architecture: %s\n' "$ARCH"
printf '[MemoWeaver] Build log: %s\n' "$LOG_FILE"
# SwiftUI's whole-module optimized build can consume substantial memory.
# Default to predictable, single-job compilation until optimized builds are
# verified on the user's Mac. Allow explicit opt-in to the old optimization.
SWIFT_OPTIMIZATION="${MEMOWEAVER_SWIFT_OPTIMIZATION:-${WORKOS_SWIFT_OPTIMIZATION:--Onone}}"
case "$SWIFT_OPTIMIZATION" in
  -Onone|-O|-Osize) ;;
  *) fail "Unsupported MEMOWEAVER_SWIFT_OPTIMIZATION=$SWIFT_OPTIMIZATION (choose -Onone, -O, or -Osize)." ;;
esac
printf '[MemoWeaver] Swift compilation: %s -j 1 (low-memory mode)\n' "$SWIFT_OPTIMIZATION"

# A native SwiftUI/AppKit binary, linked to system SQLite3 and local Apple frameworks.
# No web browser, bundled Python, Node runtime, or HTTP server is involved.
if "$SWIFTC" \
    -swift-version 5 "$SWIFT_OPTIMIZATION" -j 1 -parse-as-library -emit-executable \
    -module-name MemoWeaver \
    -sdk "$SDK" -target "${ARCH}-apple-macosx14.0" \
    -module-cache-path "$BUILD_DIR/ModuleCache" \
    -framework AppKit -framework CoreText -framework SwiftUI -framework Combine \
    -framework UniformTypeIdentifiers -framework WebKit -framework PDFKit \
    -framework UserNotifications -lsqlite3 \
    "${SOURCES[@]}" \
    -o "$STAGED_APP/Contents/MacOS/MemoWeaver" >"$LOG_FILE" 2>&1; then
  : # Success; AppKit/SwiftUI compilation and linking completed.
else
  compiler_status=$?
  printf '\n[MemoWeaver] Swift compiler exited with status %s.\n' "$compiler_status" >&2
  if [[ "$compiler_status" -ge 128 ]]; then
    printf '[MemoWeaver] Possible signal termination: signal %s (status - 128).\n' "$((compiler_status - 128))" >&2
  fi
  if [[ -s "$LOG_FILE" ]]; then
    printf '[MemoWeaver] First compiler errors (if any):\n' >&2
    grep -n -m 8 'error:' "$LOG_FILE" >&2 || true
    printf '[MemoWeaver] Compiler output (last 70 lines):\n' >&2
    tail -n 70 "$LOG_FILE" >&2 || true
  else
    printf '[MemoWeaver] Compiler log is empty; the compiler may have been terminated without diagnostics.\n' >&2
    printf '[MemoWeaver] Check macOS memory pressure and available disk space.\n' >&2
  fi
  fail "Compilation failed; existing installed app was not touched. Full log: $LOG_FILE"
fi
[[ -x "$STAGED_APP/Contents/MacOS/MemoWeaver" ]] || fail "Swift compiler did not create an executable."

printf '[MemoWeaver] Applying local ad-hoc code signature...\n'
if ! codesign --force --sign - --timestamp=none "$STAGED_APP" >>"$LOG_FILE" 2>&1; then
  fail "Local code signing failed. Full log: $LOG_FILE"
fi
codesign --verify --verbose=2 "$STAGED_APP" >>"$LOG_FILE" 2>&1 || fail "Code signature verification failed. Full log: $LOG_FILE"

# Replace only the build output after all stages succeed; never change app data.
[[ ! -L "$OUTPUT_APP" ]] || fail "Output path is a symbolic link; refusing replacement."
if [[ -e "$OUTPUT_APP" && ! -d "$OUTPUT_APP" ]]; then
  fail "Output exists but is not an app bundle: $OUTPUT_APP"
fi
PREVIOUS=""
if [[ -d "$OUTPUT_APP" ]]; then
  PREVIOUS="$OUTPUT_DIR/.MemoWeaver.previous.$$.app"
  mv "$OUTPUT_APP" "$PREVIOUS" || fail "Could not move aside earlier build."
fi
if ! mv "$STAGED_APP" "$OUTPUT_APP"; then
  if [[ -n "$PREVIOUS" && -d "$PREVIOUS" ]]; then mv "$PREVIOUS" "$OUTPUT_APP" || true; fi
  fail "Could not publish build; previous build was restored if possible."
fi
if [[ -n "$PREVIOUS" && -d "$PREVIOUS" ]]; then rm -rf -- "$PREVIOUS"; fi

printf '\n[MemoWeaver] Build complete: %s\n' "$OUTPUT_APP"
printf '[MemoWeaver] Install: ./install.sh --user\n'
