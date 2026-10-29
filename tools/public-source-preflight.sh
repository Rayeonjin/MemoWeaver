#!/bin/bash
# Conservative no-network public repository file scan. No data mutation.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
FAILED=0
if [[ ! -s LICENSE || ! -s NOTICE || ! -s TRADEMARKS.md || ! -s AGENTS.md ]]; then
  echo 'FAIL: required source/attribution/brand documents are missing' >&2
  FAILED=1
fi
if [[ ! -s WorkOSMac/Resources/official-diagrams.js || ! -s WorkOSMac/Resources/katex-mathml.js ]]; then
  echo 'FAIL: offline renderer resources are missing' >&2
  FAILED=1
fi
while IFS= read -r file; do
  case "$file" in
    */.git/*) continue ;;
    *.sqlite|*.sqlite3|*.sqlite-*|*.sqlite3-*|*.db|*.db-*|*.pem|*.p12|*.p8|*.key|*.mobileprovision|*.provisionprofile|*.zip|*.tar.gz|*.tgz|*/.env|*/.env.*|*.app/*)
      echo "FAIL: file not suitable for public Git: $file" >&2
      FAILED=1 ;;
  esac
  case "$file" in
    */Attachments/*|*/Backups/*|*/UserData/*|*/LocalData/*)
      echo "FAIL: possible user data file: $file" >&2
      FAILED=1 ;;
  esac
done < <(find . -type f -not -path './.git/*' -print)
if grep -R -I -n -E '(/Users/[[:alnum:]_.-]+/|github_pat_[[:alnum:]_]{15,}|ghp_[[:alnum:]]{20,}|-----BEGIN (OPENSSH|RSA|EC|PRIVATE) PRIVATE KEY-----)' WorkOSMac Vendor Tests docs tools README.md AGENTS.md 2>/dev/null | head -n 12; then
  echo 'FAIL: possible personal paths or credentials found (inspect lines above)' >&2
  FAILED=1
fi
if [[ "$FAILED" -eq 0 ]]; then
  echo 'PASS: no common sensitive files/credential patterns detected.'
  echo 'NOTE: this does NOT certify complete third-party license compliance.'
  echo 'NOTE: review the owner credit/brand policy and license audit manually.'
else
  exit 1
fi
