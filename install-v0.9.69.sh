#!/bin/bash
# MemoWeaver v0.9.69 Build 102: offline d3-force memory map build/install launcher.
# Safe verification: static/native smoke and full CLT build before optional install.
# Preserves com.local.workos.notes and ~/Library/Application Support/WorkOS/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT"
if [[ "$(uname -s)" != Darwin ]]; then
  printf '[MemoWeaver] macOS 14+ and Apple Command Line Tools required.\n' >&2
  exit 1
fi
run_tests() {
  # Historical version/hash assertions stay frozen. Run behavior checks against
  # the current source, including the isolated native navigation/link harness.
  local test
  local test_directory="$ROOT/scripts/tests"
  local -a tests=(
    test-d3-force-map.sh
    test-business-memory-map.sh
    test-ai-relations.sh
    test-virtual-memory.sh
    test-update-check.sh
    test-third-party-licenses.sh
    test-v0.9.65-core.sh
    test-side-preview.sh
    test-v0.9.59-ratio-cycle.sh
    test-v0.9.51-notebooks.sh
    test-v0.9.27-pinned-paste-ui.sh
    test-v0.9.65-native.sh
  )
  for test in "${tests[@]}"; do
    [[ -x "$test_directory/$test" ]] || {
      printf '[MemoWeaver] Missing or non-executable QA script: %s\n' "$test" >&2
      return 1
    }
    printf '[MemoWeaver] Testing: %s\n' "$test"
    "$test_directory/$test" || return $?
  done
  printf '[MemoWeaver] Source/Foundation/AppKit smoke tests passed.\n'
}
case "${1:-}" in
  --help|-h)
    printf 'Usage: ./install-v0.9.69.sh [--verify|--build-only]\n'
    printf '  No options: compile and install /Applications/MemoWeaver.app.\n'
    printf '  --verify: run source/AppKit tests and FULL app build (does NOT install).\n  --build-only: compile app only, do NOT replace the installed app.\n'
    exit 0
    ;;
  --build-only)
    [[ $# -eq 1 ]] || { printf 'Unexpected arguments.\n' >&2; exit 2; }
    exec "$ROOT/build.sh"
    ;;
  --verify)
    [[ $# -eq 1 ]] || { printf 'Unexpected arguments.\n' >&2; exit 2; }
    run_tests
    printf '[MemoWeaver] Compiling the entire macOS app as part of --verify (no installation).\n'
    "$ROOT/build.sh"
    printf '[MemoWeaver] Full macOS build passed. Installed app was not touched.\n'
    exit
    ;;
  '') [[ $# -eq 0 ]] || { printf 'Unexpected arguments.\n' >&2; exit 2; } ;;
  *) printf 'Unexpected argument: %s\n' "$1" >&2; exit 2 ;;
esac
on_error() {
  local status=$?
  printf '\n[MemoWeaver] Installation stopped (exit %s).\n' "$status" >&2
  printf '[MemoWeaver] If Swift compilation failed, open: %s/build/Logs/swiftc-release.log\n' "$ROOT" >&2
  exit "$status"
}
trap on_error ERR
printf '[MemoWeaver] Starting build and installation. Optional tests: ./install-v0.9.69.sh --verify\n'
# Standard installation always targets Finder's shared Applications folder.
# An existing per-user copy must not silently change the destination.
printf '[MemoWeaver] Selected: /Applications (standard installation).\n'
"$ROOT/install.sh" --yes --open
printf '[MemoWeaver] Installation command completed.\n'
