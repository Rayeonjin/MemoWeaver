#!/bin/bash
# Scan the files Git would upload, including tracked files that now match
# ignore rules. Generated build outputs are not part of a source publication.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
FAILED=0
REPORT="$(mktemp "${TMPDIR:-/tmp}/memoweaver-source-scan.XXXXXXXX")"
trap 'rm -f -- "$REPORT"' EXIT
if [[ ! -s LICENSE || ! -s NOTICE || ! -s TRADEMARKS.md || ! -s AGENTS.md ]]; then
  echo 'FAIL: required source/attribution/brand documents are missing' >&2
  FAILED=1
fi
if [[ ! -s WorkOSMac/Resources/official-diagrams.js || ! -s WorkOSMac/Resources/katex-mathml.js ]]; then
  echo 'FAIL: offline renderer resources are missing' >&2
  FAILED=1
fi
source_files() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git ls-files --cached --others --exclude-standard -z
  else
    find . -type d \( -path './.git' -o -path './build' -o -path './DerivedData' -o -name node_modules \) -prune -o -type f -print0
  fi
}
PATTERN='(/Users/[[:alnum:]_.-]+/|github_pat_[[:alnum:]_]{15,}|ghp_[[:alnum:]]{20,}|-----BEGIN (OPENSSH|RSA|EC|PRIVATE) PRIVATE KEY-----)'
while IFS= read -r -d '' file; do
  case "$file" in
    *.sqlite|*.sqlite3|*.sqlite-*|*.sqlite3-*|*.db|*.db-*|*.pem|*.p12|*.p8|*.key|*.mobileprovision|*.provisionprofile|*.zip|*.tar.gz|*.tgz|.env|.env.*|*/.env|*/.env.*|*.app/*)
      echo "FAIL: file not suitable for public Git: $file" >&2
      FAILED=1 ;;
  esac
  case "/$file" in
    */Attachments/*|*/Backups/*|*/UserData/*|*/LocalData/*|*/PRIVATE_KEEP_OFF_GITHUB/*|*/build/*)
      echo "FAIL: possible user data or build output: $file" >&2
      FAILED=1 ;;
  esac
  if [[ ! -f "$file" ]]; then
    echo "FAIL: indexed file is missing: $file" >&2
    FAILED=1
    continue
  fi
  # Collect matches before truncating output: grep | head under pipefail can
  # otherwise hide a positive scan when grep exits on SIGPIPE.
  if LC_ALL=C grep -I -n -E -- "$PATTERN" "$file" >> "$REPORT"; then
    printf 'File: %s\n' "$file" >> "$REPORT"
    FAILED=1
  else
    status=$?
    if [[ "$status" -ne 1 ]]; then
      echo "FAIL: could not scan: $file" >&2
      FAILED=1
    fi
  fi
done < <(source_files)
if [[ -s "$REPORT" ]]; then
  head -n 24 "$REPORT"
  echo 'FAIL: possible personal paths or credentials found (inspect lines above)' >&2
fi
if [[ "$FAILED" -eq 0 ]]; then
  echo 'PASS: Git source candidates contain no common sensitive files/credential patterns.'
  echo 'NOTE: this does NOT certify complete third-party license compliance.'
else
  exit 1
fi
