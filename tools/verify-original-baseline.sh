#!/bin/bash
# Compare the transferred original files to their v0.9.64 byte-level baseline.
# Before the first weekly code change only. Subsequent edits should differ.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
shasum -a 256 -c docs/ORIGINAL_BASELINE_FILES_v0.9.64.sha256
