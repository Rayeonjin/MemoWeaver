#!/bin/bash
# Simulate legacy -> MemoWeaver.app installation/rollback without real app/data.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/memoweaver-install-test.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/project/build/Release/MemoWeaver.app/Contents/MacOS" "$TMP/home/Applications"
cp "$ROOT/install.sh" "$TMP/project/install.sh"
cp "$ROOT/WorkOSMac/Info.plist" "$TMP/project/build/Release/MemoWeaver.app/Contents/Info.plist"
printf 'new app executable\n' > "$TMP/project/build/Release/MemoWeaver.app/Contents/MacOS/MemoWeaver"
chmod +x "$TMP/project/build/Release/MemoWeaver.app/Contents/MacOS/MemoWeaver"
cat > "$TMP/bin/uname" <<'EOF'
#!/bin/sh
[ "${1:-}" = '-s' ] && { echo Darwin; exit 0; }
exec /usr/bin/uname "$@"
EOF
cat > "$TMP/bin/codesign" <<'EOF'
#!/bin/sh
last=''
for arg do last="$arg"; done
if [ "${SIMULATE_BAD_SIGNATURE:-0}" = 1 ] && [ "${last##*/}" = 'MemoWeaver.app' ] && [ "${last#*build/Release}" = "$last" ]; then
  exit 1
fi
exit 0
EOF
cat > "$TMP/bin/ditto" <<'EOF'
#!/bin/sh
exec cp -R "$1" "$2"
EOF
cat > "$TMP/bin/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH"
export HOME="$TMP/home"
export LANG="${LANG:-C.UTF-8}"

# Existing Korean-name install, plus a note database whose bytes must not change.
mkdir -p "$HOME/Applications/기억의 집.app/Contents/MacOS" "$HOME/Library/Application Support/WorkOS"
printf 'old app\n' > "$HOME/Applications/기억의 집.app/Contents/MacOS/WorkOS"
printf 'existing local notes must remain\n' > "$HOME/Library/Application Support/WorkOS/WorkOS.sqlite"
cp "$HOME/Library/Application Support/WorkOS/WorkOS.sqlite" "$TMP/db-original"
"$TMP/project/install.sh" --user --yes --install-only > "$TMP/success.log" 2>&1
[[ -d "$HOME/Applications/MemoWeaver.app" ]] || { cat "$TMP/success.log"; exit 1; }
[[ ! -d "$HOME/Applications/기억의 집.app" ]] || { echo 'Old named app not migrated'; exit 1; }
find "$HOME/Applications" -maxdepth 1 -name '.MemoWeaver.backup.*.app' -type d | grep -q . || { echo 'Hidden app backup missing'; exit 1; }
cmp "$TMP/db-original" "$HOME/Library/Application Support/WorkOS/WorkOS.sqlite"
echo 'PASS brand install simulation: renamed app, backup retained, SQLite bytes unchanged'

# Failure path: a legacy WorkOS installation must be restored to its old name
# if post-install verification fails.
rm -rf -- "$HOME/Applications/MemoWeaver.app"
mkdir -p "$HOME/Applications/WorkOS.app/Contents/MacOS"
printf 'second old app\n' > "$HOME/Applications/WorkOS.app/Contents/MacOS/WorkOS"
export SIMULATE_BAD_SIGNATURE=1
if "$TMP/project/install.sh" --user --yes --install-only > "$TMP/failure.log" 2>&1; then
  echo 'Failure case unexpectedly succeeded' >&2
  exit 1
fi
[[ -d "$HOME/Applications/WorkOS.app" && ! -e "$HOME/Applications/MemoWeaver.app" ]] || { cat "$TMP/failure.log"; exit 1; }
cmp "$TMP/db-original" "$HOME/Library/Application Support/WorkOS/WorkOS.sqlite"
echo 'PASS brand install simulation: invalid installed signature rolls back to WorkOS.app'
