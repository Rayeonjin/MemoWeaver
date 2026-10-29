#!/bin/bash
# MemoWeaver pre-migration safety snapshot (no source DB modifications).
# The legacy WorkOS path is intentional; do not rename or migrate it here.
set -euo pipefail
if [[ $# -ne 0 ]]; then
  printf 'Usage: ./backup-before-real-use.sh\n' >&2
  exit 2
fi
for name in MemoWeaver WorkOS '기억의 집'; do
  if command -v pgrep >/dev/null 2>&1 && pgrep -x "$name" >/dev/null 2>&1; then
    printf '[MemoWeaver] Close %s before backing up SQLite and its WAL files.\n' "$name" >&2
    exit 1
  fi
done
SOURCE_PARENT="$HOME/Library/Application Support"
SOURCE="$SOURCE_PARENT/WorkOS"
if [[ ! -f "$SOURCE/WorkOS.sqlite" ]]; then
  printf '[MemoWeaver] Existing database not found: %s/WorkOS.sqlite\n' "$SOURCE" >&2
  exit 1
fi
DEST_DIR="${MEMOWEAVER_BACKUP_DIR:-$HOME/Documents/MemoWeaver Backups}"
umask 077
mkdir -p "$DEST_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
DEST="$DEST_DIR/MemoWeaver-before-real-use-${STAMP}-$$.tar.gz"
trap 'rm -f -- "$DEST"' ERR
tar -czf "$DEST" -C "$SOURCE_PARENT" WorkOS
tar -tzf "$DEST" >/dev/null
printf '[MemoWeaver] Verified complete local data archive:\n%s\n' "$DEST"
printf '[MemoWeaver] Included: SQLite DB, WAL if present, attachments, recovery drafts, and other WorkOS files.\n'
printf '[MemoWeaver] The source data directory was NOT modified. Keep this archive separate from the Mac.\n'
