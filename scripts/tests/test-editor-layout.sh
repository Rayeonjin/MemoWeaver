#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
"$ROOT/scripts/tests/test-editor-wrap.sh"
