#!/bin/bash
# MemoWeaver: CLT build + safe app replacement.
# Preserve the legacy bundle identifier and on-disk note/settings paths.
# The user-visible app and executable names are now MemoWeaver.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
APP="$ROOT/build/Release/MemoWeaver.app"
INSTALL_DIR=/Applications
INSTALL_KIND=system
YES=0
OPEN_AFTER=0
INSTALL_ONLY=0

usage() {
  cat <<'HELP'
Usage: ./install.sh [--user] [--yes] [--open] [--install-only]

  ./install.sh --user   Build and install ~/Applications/MemoWeaver.app
  ./install.sh          Build and install /Applications/MemoWeaver.app
  ./install.sh --yes    Allow replacement/renaming of an existing app
  ./install.sh --open   Open new app after installation
  ./install.sh --install-only  Install already compiled MemoWeaver.app
  ./build.sh            Build only

Also recognizes previous 기억의 집.app and WorkOS.app in the selected
Applications folder. Old app bundles are moved to hidden, date-stamped
backups before the new app is installed. Existing notes and preferences
in ~/Library/Application Support/WorkOS/ remain unchanged.
HELP
}
fail() { printf '\n[MemoWeaver] ERROR: %s\n' "$*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) INSTALL_DIR="$HOME/Applications"; INSTALL_KIND=user ;;
    --yes) YES=1 ;;
    --open) OPEN_AFTER=1 ;;
    --install-only) INSTALL_ONLY=1 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
  shift
done
[[ "$(uname -s)" == Darwin ]] || fail "Install must run on macOS."

if [[ $INSTALL_ONLY -eq 1 ]]; then
  printf '[MemoWeaver] Step 1/2: using existing build\n'
else
  printf '[MemoWeaver] Step 1/2: compiling with Apple Command Line Tools swiftc\n'
  "$ROOT/build.sh"
fi
[[ -d "$APP" && -x "$APP/Contents/MacOS/MemoWeaver" ]] || fail "Built app missing. Run ./build.sh first."
command -v codesign >/dev/null 2>&1 || fail "macOS codesign utility is missing."
codesign --verify --verbose=2 "$APP" >/dev/null 2>&1 || fail "Build signature invalid. Rebuild first."
read_plist_string() {
  local key="$1"
  awk -v k="$key" 'index($0, "<key>" k "</key>") { getline; gsub(/^[[:space:]]*<string>|<\/string>[[:space:]]*$/, ""); print; exit }' "$APP/Contents/Info.plist"
}
APP_VERSION="$(read_plist_string CFBundleShortVersionString)"
APP_BUILD="$(read_plist_string CFBundleVersion)"
APP_IDENTIFIER="$(read_plist_string CFBundleIdentifier)"
[[ "$APP_IDENTIFIER" == com.local.workos.notes ]] || fail "Unexpected bundle ID; cannot confirm existing data compatibility."
printf '[MemoWeaver] Version: %s (build %s)\n' "${APP_VERSION:-unknown}" "${APP_BUILD:-unknown}"

DEST="$INSTALL_DIR/MemoWeaver.app"
LEGACY_HOME="$INSTALL_DIR/기억의 집.app"
LEGACY_OLD="$INSTALL_DIR/WorkOS.app"
if [[ "$INSTALL_KIND" == user ]]; then
  mkdir -p "$INSTALL_DIR" || fail "Cannot create $INSTALL_DIR."
else
  [[ -d "$INSTALL_DIR" ]] || fail "System Applications directory missing."
fi
for path in "$DEST" "$LEGACY_HOME" "$LEGACY_OLD"; do
  [[ ! -L "$path" ]] || fail "Refusing to overwrite symbolic link: $path"
  [[ ! -e "$path" || -d "$path" ]] || fail "Existing destination is not an app directory: $path"
done
# A previous brand already wins; otherwise promote an old install to the new name.
REPLACED=""
if [[ -d "$DEST" ]]; then REPLACED="$DEST"
elif [[ -d "$LEGACY_HOME" ]]; then REPLACED="$LEGACY_HOME"
elif [[ -d "$LEGACY_OLD" ]]; then REPLACED="$LEGACY_OLD"
fi
for old in "$LEGACY_HOME" "$LEGACY_OLD"; do
  if [[ -d "$old" && "$old" != "$REPLACED" ]]; then
    printf '[MemoWeaver] NOTICE: other legacy installation remains: %s\n' "$old"
  fi
done
if [[ -n "$REPLACED" && $YES -ne 1 ]]; then
  [[ -t 0 ]] || fail "Existing app found; use --yes for unattended upgrade."
  printf '[MemoWeaver] Existing app: %s\n' "$REPLACED"
  printf 'Back up the old app and install MemoWeaver.app? (SQLite notes remain.) [y/N]: '
  read -r answer || true
  case "${answer:-}" in y|Y|yes|YES) ;; *) fail "Installation canceled." ;; esac
fi
# Refuse upgrades while either historic or new executable is running.
if command -v pgrep >/dev/null 2>&1 &&
   (pgrep -x MemoWeaver >/dev/null 2>&1 || pgrep -x WorkOS >/dev/null 2>&1); then
  fail "MemoWeaver or the earlier installed app is running. Quit it first."
fi
command -v ditto >/dev/null 2>&1 || fail "macOS ditto utility is missing."
USE_SUDO=0
if [[ ! -w "$INSTALL_DIR" ]]; then
  [[ "$INSTALL_KIND" != user ]] || fail "No write access to $INSTALL_DIR."
  command -v sudo >/dev/null 2>&1 || fail "No write access to /Applications; try --user."
  [[ -t 0 ]] || fail "System installation needs admin permission; try --user."
  sudo -v || fail "Admin permission declined."
  USE_SUDO=1
fi
run_cmd() {
  if [[ $USE_SUDO -eq 1 ]]; then sudo "$@"; else "$@"; fi
}
printf '[MemoWeaver] Step 2/2: install to %s\n' "$DEST"
STAGE_DIR="$(run_cmd mktemp -d "$INSTALL_DIR/.memoweaver-install.XXXXXXXX")" || fail "Could not create staging directory."
STAGED="$STAGE_DIR/MemoWeaver.app"
BACKUP="$INSTALL_DIR/.MemoWeaver.backup.$(date +%Y%m%d-%H%M%S).$$.app"
HAD_BACKUP=0
cleanup_staging() {
  if [[ -n "${STAGE_DIR:-}" && -d "$STAGE_DIR" ]]; then
    run_cmd rm -rf -- "$STAGE_DIR" || true
  fi
}
trap cleanup_staging EXIT
run_cmd ditto "$APP" "$STAGED" || fail "Staging failed; existing app is untouched."
run_cmd test -x "$STAGED/Contents/MacOS/MemoWeaver" || fail "Staged app executable missing."
if [[ -n "$REPLACED" ]]; then
  run_cmd mv "$REPLACED" "$BACKUP" || fail "Could not preserve existing app."
  HAD_BACKUP=1
fi
if ! run_cmd mv "$STAGED" "$DEST"; then
  if [[ $HAD_BACKUP -eq 1 ]]; then
    run_cmd mv "$BACKUP" "$REPLACED" || true
  fi
  fail "Installation failed; previous app restored if possible."
fi
if ! codesign --verify --verbose=2 "$DEST" >/dev/null 2>&1; then
  run_cmd mv "$DEST" "$STAGE_DIR/failed-MemoWeaver.app" || fail "Verification failed and could not move new bundle. Backup: $BACKUP"
  if [[ $HAD_BACKUP -eq 1 ]]; then
    run_cmd mv "$BACKUP" "$REPLACED" || fail "Signature check and rollback failed. Old app backup: $BACKUP"
    fail "Signature check failed; original app restored."
  fi
  fail "Signature check failed; failed app removed."
fi
# Refresh LaunchServices' view of the installed bundle without removing its
# signature or touching the user's notes.
run_cmd touch "$DEST" || true
printf '\n[MemoWeaver] Installed: %s\n' "$DEST"
if [[ $HAD_BACKUP -eq 1 ]]; then printf '[MemoWeaver] Previous app backup: %s\n' "$BACKUP"; fi
printf '[MemoWeaver] Existing notes and settings retained (legacy storage path unchanged).\n'
if [[ $OPEN_AFTER -eq 1 ]]; then open "$DEST" || fail "Installed, but could not open the app."; fi
