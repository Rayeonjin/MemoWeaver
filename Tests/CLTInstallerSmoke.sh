#!/bin/bash
# Safe Unix-host simulation only; never claims to build SwiftUI on macOS.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf -- "$SCRATCH"' EXIT
mkdir -p "$SCRATCH/bin" "$SCRATCH/home" "$SCRATCH/CommandLineTools" "$SCRATCH/sdk"
LOG="$SCRATCH/commands.log"
: > "$LOG"
cat > "$SCRATCH/bin/uname" <<'EOF'
#!/bin/bash
case "${1:-}" in -s) printf 'Darwin\n';; -m) printf 'arm64\n';; *) printf 'Darwin\n';; esac
EOF
cat > "$SCRATCH/bin/sw_vers" <<'EOF'
#!/bin/bash
printf '15.6\n'
EOF
cat > "$SCRATCH/bin/xcrun" <<'EOF'
#!/bin/bash
printf 'xcrun %s\n' "$*" >> "$MOCK_LOG"
case "$*" in
  *--find\ swiftc*) printf '%s\n' "$MOCK_BIN/swiftc" ;;
  *--show-sdk-path*) printf '%s\n' "$MOCK_SDK" ;;
  *) exit 2 ;;
esac
EOF
cat > "$SCRATCH/bin/swiftc" <<'EOF'
#!/bin/bash
printf 'swiftc %s\n' "$*" >> "$MOCK_LOG"
if [[ "${MOCK_COMPILE_FAIL:-0}" == 1 ]]; then
  printf 'WorkOSApp.swift:1:1: error: simulated compiler error\n' >&2
  exit 1
fi
out=''
while [[ $# -gt 0 ]]; do
  case "$1" in -o) shift; out="$1";; esac
  shift
done
[[ -n "$out" ]] || exit 2
printf '#!/bin/sh\nexit 0\n' > "$out"
chmod +x "$out"
EOF
cat > "$SCRATCH/bin/sips" <<'EOF'
#!/bin/bash
printf 'sips %s\n' "$*" >> "$MOCK_LOG"
output=''
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --out ]]; then shift; output="$1"; fi
  shift
done
[[ -n "$output" ]] || exit 2
printf 'mock icon' > "$output"
EOF
cat > "$SCRATCH/bin/iconutil" <<'EOF'
#!/bin/bash
printf 'iconutil %s\n' "$*" >> "$MOCK_LOG"
output=''
while [[ $# -gt 0 ]]; do
  if [[ "$1" == -o ]]; then shift; output="$1"; fi
  shift
done
[[ -n "$output" ]] || exit 2
printf 'mock icns' > "$output"
EOF
cat > "$SCRATCH/bin/plutil" <<'EOF'
#!/bin/bash
exit 0
EOF
cat > "$SCRATCH/bin/codesign" <<'EOF'
#!/bin/bash
printf 'codesign %s\n' "$*" >> "$MOCK_LOG"
if [[ "${MOCK_INSTALLED_SIGNATURE_FAIL:-0}" == 1 && "$*" == *'Applications/기억의 집.app'* && "$*" == *'--verify'* ]]; then
  exit 1
fi
exit 0
EOF
cat > "$SCRATCH/bin/ditto" <<'EOF'
#!/bin/bash
cp -R "$1" "$2"
EOF
cat > "$SCRATCH/bin/pgrep" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$SCRATCH/bin/"*
export MOCK_LOG="$LOG" MOCK_BIN="$SCRATCH/bin" MOCK_SDK="$SCRATCH/sdk"
export WORKOS_CLT_DIR="$SCRATCH/CommandLineTools" HOME="$SCRATCH/home"
export PATH="$SCRATCH/bin:$PATH"

# A copy of the source; do not fill the original package with mock binaries.
cp -R "$ROOT" "$SCRATCH/workos"
cd "$SCRATCH/workos"
./install.sh --user --yes > "$SCRATCH/first.log"
APP="$HOME/Applications/기억의 집.app"
[[ -x "$APP/Contents/MacOS/WorkOS" ]] || { echo 'First install failed'; exit 1; }
[[ -f "$APP/Contents/Info.plist" ]] || exit 1
[[ -s "$APP/Contents/Resources/MemoryHome.icns" ]] || { echo 'App icon missing'; exit 1; }
grep -q '<key>CFBundleIconFile</key>' "$APP/Contents/Info.plist" || { echo 'Icon plist reference missing'; exit 1; }
grep -q '<string>0.9.5</string>' "$APP/Contents/Info.plist" || { echo 'Version mismatch'; exit 1; }
printf 'previous-install' > "$APP/Contents/Resources/install-marker"

# A simulated compiler failure must preserve the prior install.
if MOCK_COMPILE_FAIL=1 ./install.sh --user --yes > "$SCRATCH/fail.log" 2>&1; then
  echo 'Installer accepted failed compile' >&2; exit 1
fi
[[ "$(cat "$APP/Contents/Resources/install-marker")" == previous-install ]] || { echo 'Failed build changed existing install' >&2; exit 1; }

# On success the old bundle is saved and the user app is replaced.
./install.sh --user --yes > "$SCRATCH/update.log"
[[ -x "$APP/Contents/MacOS/WorkOS" ]] || exit 1
[[ ! -e "$APP/Contents/Resources/install-marker" ]] || exit 1
find "$HOME/Applications" -name '.MemoryHome.backup.*.app' | grep -q . || { echo 'Backup missing'; exit 1; }

# An installed-bundle signature failure must roll back to the previous app.
printf 'current-release' > "$APP/Contents/Resources/install-marker"
if MOCK_INSTALLED_SIGNATURE_FAIL=1 ./install.sh --user --yes > "$SCRATCH/signature-fail.log" 2>&1; then
  echo 'Installer accepted failed signature' >&2; exit 1
fi
[[ "$(cat "$APP/Contents/Resources/install-marker")" == current-release ]] || { echo 'Signature failure did not restore previous install' >&2; exit 1; }

# First upgrade from legacy WorkOS.app: original installed bundle is backed up;
# app data directory must not change. The source build itself is already valid.
mkdir -p "$HOME/Library/Application Support/WorkOS"
printf 'keep-this-data' > "$HOME/Library/Application Support/WorkOS/WorkOS.sqlite"
rm -rf "$APP"
LEGACY="$HOME/Applications/WorkOS.app"
mkdir -p "$LEGACY/Contents/Resources"
printf 'legacy-marker' > "$LEGACY/Contents/Resources/install-marker"
./install.sh --user --yes --install-only > "$SCRATCH/migration.log"
[[ -x "$APP/Contents/MacOS/WorkOS" ]] || { echo 'Legacy migration did not install app' >&2; exit 1; }
[[ ! -e "$LEGACY" ]] || { echo 'Legacy app was not moved to backup' >&2; exit 1; }
# Ensure the legacy bundle itself survived, not just any earlier app backup.
found_legacy_backup=0
for item in "$HOME"/Applications/.MemoryHome.backup.*.app; do
  if [[ -f "$item/Contents/Resources/install-marker" ]] &&
     [[ "$(cat "$item/Contents/Resources/install-marker")" == legacy-marker ]]; then
    found_legacy_backup=1
  fi
done
[[ $found_legacy_backup -eq 1 ]] || { echo 'Legacy app backup was not preserved' >&2; exit 1; }
[[ "$(cat "$HOME/Library/Application Support/WorkOS/WorkOS.sqlite")" == keep-this-data ]] || { echo 'Note data changed' >&2; exit 1; }

# --install-only must reuse an existing build and never invoke swiftc.
compile_count_before=$(grep -c '^swiftc ' "$LOG")
./install.sh --user --yes --install-only > "$SCRATCH/install-only.log"
compile_count_after=$(grep -c '^swiftc ' "$LOG")
[[ "$compile_count_before" -eq "$compile_count_after" ]] || { echo '--install-only unexpectedly compiled' >&2; exit 1; }
[[ -x "$APP/Contents/MacOS/WorkOS" ]] || { echo '--install-only failed' >&2; exit 1; }

# No Xcode project nor xcodebuild is invoked by the build.
! grep -qi 'xcodebuild' "$LOG"
! find "$SCRATCH/workos" -name '*.xcodeproj' | grep -q .
printf 'PASS: CLT-only install, compile failure safety, update/backup, signature-failure rollback, install-only\n'
