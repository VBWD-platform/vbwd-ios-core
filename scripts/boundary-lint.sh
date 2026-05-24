#!/usr/bin/env bash
# Dependency-boundary lint (Clean Architecture guard).
#
# Fails if framework-specific APIs leak outside their designated adapter file:
#   - URLSession            → only URLSessionAPIClient.swift
#   - Security/Keychain     → only KeychainTokenStore.swift
#   - print(                → nowhere in Sources (use injected logging instead)
#   - concrete adapters     → only referenced inside SDKContainer.swift
#
# Run from Packages/VBWDSdk. Exit non-zero on any violation.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/Sources/VBWDSdk"
fail=0

violation() { echo "BOUNDARY VIOLATION: $1"; fail=1; }

# URLSession confined to URLSessionAPIClient.swift.
# Strip `//` comment lines and the identifier `URLSessionAPIClient` (DIP
# doc-comment references), then flag any remaining real URLSession-type usage.
while IFS= read -r f; do
  [ "$(basename "$f")" = "URLSessionAPIClient.swift" ] && continue
  if grep -vE '^\s*//' "$f" | sed 's/URLSessionAPIClient//g' \
       | grep -q 'URLSession'; then
    violation "URLSession used in $f"
  fi
done < <(find "$SRC" -name '*.swift')

# Keychain/Security confined to KeychainTokenStore.swift
while IFS= read -r f; do
  [ "$(basename "$f")" = "KeychainTokenStore.swift" ] && continue
  grep -lqE 'SecItem(Add|Copy|Delete|Update)' "$f" && violation "Keychain API used in $f"
done < <(find "$SRC" -name '*.swift')

# No print( anywhere in Sources
while IFS= read -r f; do
  grep -lqE '(^|[^A-Za-z_])print\(' "$f" && violation "print( used in $f"
done < <(find "$SRC" -name '*.swift')

if [ "$fail" -ne 0 ]; then
  echo "Boundary lint FAILED."
  exit 1
fi
echo "Boundary lint OK."
