#!/bin/bash
# Legacy alias: v0.9.20 intentionally replaced v0.9.19 SwiftUI drag grips.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
exec "$ROOT/scripts/tests/test-v0.9.20-native-split.sh" "$@"
