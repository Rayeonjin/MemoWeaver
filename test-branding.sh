#!/bin/bash
# Offline/portable static checks for MemoWeaver brand integration.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$ROOT"
pass() { printf 'PASS %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
plist_string() {
  local key="$1"
  awk -v k="$key" 'index($0, "<key>" k "</key>") { getline; gsub(/^[[:space:]]*<string>|<\/string>[[:space:]]*$/, ""); print; exit }' WorkOSMac/Info.plist
}
[[ "$(plist_string CFBundleDisplayName)" == MemoWeaver ]] || fail 'Display name'
[[ "$(plist_string CFBundleName)" == MemoWeaver ]] || fail 'Bundle name'
[[ "$(plist_string CFBundleIdentifier)" == com.local.workos.notes ]] || fail 'Bundle ID changed'
[[ "$(plist_string CFBundleExecutable)" == MemoWeaver ]] || fail 'Executable branding'
[[ "$(plist_string CFBundleIconFile)" == MemoWeaver.icns ]] || fail 'Icon name'
[[ "$(plist_string CFBundleShortVersionString)" == 0.9.60 ]] || fail 'App version'
[[ "$(plist_string CFBundleVersion)" == 93 ]] || fail 'Build number'
pass 'Info.plist branding with legacy bundle identity'

[[ -s WorkOSMac/Resources/MemoWeaverIcon.png ]] || fail 'App icon PNG missing'
[[ -s Brand/MemoWeaver_Icon_Concept.png ]] || fail 'Original brand asset missing'
[[ -s Brand/MemoWeaver_Naming_and_Icon.md ]] || fail 'Brand decisions missing'
[[ ! -e WorkOSMac/Resources/MemoryHomeIcon.png ]] || fail 'Old icon still packaged'
file -b WorkOSMac/Resources/MemoWeaverIcon.png | grep -Eq '1024 x 1024.*RGBA' || fail 'Expected 1024 RGBA PNG'
pass 'App icon asset structure'

for shfile in build.sh install.sh install-v0.9.15.sh; do
  bash -n "$shfile" || fail "Shell syntax: $shfile"
done
grep -Fq 'build/Release/MemoWeaver.app' build.sh || fail 'Wrong build directory'
grep -Fq 'MemoWeaverIcon.png' build.sh || fail 'Wrong build icon source'
grep -Fq 'MemoWeaver.icns' build.sh || fail 'Wrong .icns output'
grep -Fq 'DEST="$INSTALL_DIR/MemoWeaver.app"' install.sh || fail 'Wrong install destination'
grep -Fq 'LEGACY_HOME="$INSTALL_DIR/기억의 집.app"' install.sh || fail 'Missing Korean legacy detection'
grep -Fq 'LEGACY_OLD="$INSTALL_DIR/WorkOS.app"' install.sh || fail 'Missing WorkOS legacy detection'
grep -Fq 'pgrep -x WorkOS' install.sh || fail 'Missing legacy process guard'
grep -Fq 'pgrep -x MemoWeaver' install.sh || fail 'Missing new process guard'
pass 'Build and installer scripts recognize old app names'

grep -Fq '.appendingPathComponent("WorkOS", isDirectory: true)' WorkOSMac/Storage.swift || fail 'SQLite directory changed'
grep -Fq 'databaseURL = directory.appendingPathComponent("WorkOS.sqlite")' WorkOSMac/Storage.swift || fail 'SQLite filename changed'
grep -Fq '"MemoryHomeOfficialDiagrams"' WorkOSMac/OfficialDiagramRuntime.swift || fail 'Diagram bridge changed'
grep -Fq '"memoryhome.typography.fontSize"' WorkOSMac/WorkOSApp.swift || fail 'Editor preference key changed'
pass 'Data storage and official JS bridge unchanged'

if grep -nF '기억의 집' WorkOSMac/*.swift; then fail 'Old app brand in user-facing Swift UI'; fi
grep -Fq 'Window("MemoWeaver", id: "main")' WorkOSMac/WorkOSApp.swift || fail 'SwiftUI app window title wrong'
pass 'UI title uses MemoWeaver'

[[ -s WorkOSMac/Resources/official-diagrams.js && -s WorkOSMac/Resources/katex-mathml.js ]] || fail 'Bundled renderers missing'
pass 'Offline Mermaid/Markmap/KaTeX assets retained'
