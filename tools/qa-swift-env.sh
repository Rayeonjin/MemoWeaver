#!/bin/bash
# Source from a QA script after ROOT has been set. Keep compiler caches inside
# the checkout and use the same CLT SDK/target as build.sh.
if [[ "$(uname -s)" == Darwin ]]; then
  export DEVELOPER_DIR="${MEMOWEAVER_CLT_DIR:-${WORKOS_CLT_DIR:-/Library/Developer/CommandLineTools}}"
  export MEMOWEAVER_QA_SWIFTC="$(xcrun --sdk macosx --find swiftc)"
  export MEMOWEAVER_QA_SDK="$(xcrun --sdk macosx --show-sdk-path)"
  export MEMOWEAVER_QA_CACHE_DIR="$ROOT/build/QAModuleCache"
  export SWIFT_MODULECACHE_PATH="$MEMOWEAVER_QA_CACHE_DIR"
  export CLANG_MODULE_CACHE_PATH="$MEMOWEAVER_QA_CACHE_DIR"
  mkdir -p "$MEMOWEAVER_QA_CACHE_DIR"
  export PATH="$ROOT/tools/qa-bin:$PATH"
fi
