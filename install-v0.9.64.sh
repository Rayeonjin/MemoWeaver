#!/bin/bash
# MemoWeaver v0.9.64 Build 97: native zoned unified toolbar build/install launcher.
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
  # Earlier scripts assert old global toolbar groups and historical bundle
  # versions. This release verifies the native zoned toolbar and fixed source paths.
  local test
  local -a tests=(
    test-third-party-licenses.sh
    test-review-stability.sh
    test-v0.9.64-schedule.sh
    test-v0.9.64-pointer-symbols.sh
    test-v0.9.64-toolkit.sh
    test-v0.9.64-live-preview.sh
    test-v0.9.64-optimization.sh
    test-v0.9.60-brand-data.sh
    test-v0.9.59-ratio-cycle.sh
    test-v0.9.60-editor-hotpath.sh
    test-side-preview.sh
    test-v0.9.51-notebooks.sh
    test-v0.9.27-pinned-paste-ui.sh
  )
  for test in "${tests[@]}"; do
    [[ -x "$ROOT/$test" ]] || {
      printf '[MemoWeaver] Missing or non-executable QA script: %s\n' "$test" >&2
      return 1
    }
    printf '[MemoWeaver] Testing: %s\n' "$test"
    "$ROOT/$test" || return $?
  done
  printf '[MemoWeaver] Source/Foundation/AppKit smoke tests passed.\n'
}
case "${1:-}" in
  --help|-h)
    printf 'Usage: ./install-v0.9.64.sh [--verify|--build-only]\n'
    printf '  No options: compile and install MemoWeaver immediately.\n'
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
printf '[MemoWeaver] Starting build and installation. Optional tests: ./install-v0.9.64.sh --verify\n'
# Install into the existing legacy application's parent directory when possible.
# User Applications is preferred when both locations contain an existing app.
if [[ -d "$HOME/Applications/MemoWeaver.app" || -d "$HOME/Applications/기억의 집.app" || -d "$HOME/Applications/WorkOS.app" ]]; then
  printf '[MemoWeaver] Selected: ~/Applications (existing user app).\n'
  "$ROOT/install.sh" --user --yes --open
elif [[ -d '/Applications/MemoWeaver.app' || -d '/Applications/기억의 집.app' || -d '/Applications/WorkOS.app' ]]; then
  printf '[MemoWeaver] Selected: /Applications (existing system app).\n'
  "$ROOT/install.sh" --yes --open
else
  printf '[MemoWeaver] Selected: ~/Applications (new install).\n'
  "$ROOT/install.sh" --user --yes --open
fi
printf '[MemoWeaver] Installation command completed.\n'
