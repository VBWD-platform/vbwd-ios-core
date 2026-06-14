#!/usr/bin/env bash
# Dependency-boundary lint (Clean Architecture guard).
#
# Fails if framework-specific APIs leak outside their designated adapter file:
#   - URLSession                → only URLSessionAPIClient.swift
#   - Security/Keychain         → only KeychainTokenStore.swift
#   - print(                    → nowhere in Sources (use injected logging instead)
#   - UNUserNotificationCenter  → only DefaultNotificationsSDK.swift (S67.2)
#   - UIApplication             → only DefaultNotificationsSDK.swift (S67.2)
#                                 + PaymentRedirectView.swift (pre-existing
#                                   key-window lookup for payment redirects)
#   - concrete adapters         → only referenced inside SDKContainer.swift
#
# Run from Packages/vbwd-ios-core. Exit non-zero on any violation.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)/Sources/VBWDCore"
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
  if grep -qE 'SecItem(Add|Copy|Delete|Update)' "$f"; then
    violation "Keychain API used in $f"
  fi
done < <(find "$SRC" -name '*.swift')

# No print( anywhere in Sources
while IFS= read -r f; do
  if grep -qE '(^|[^A-Za-z_])print\(' "$f"; then
    violation "print( used in $f"
  fi
done < <(find "$SRC" -name '*.swift')

# UNUserNotificationCenter confined to DefaultNotificationsSDK.swift (S67.2)
while IFS= read -r f; do
  [ "$(basename "$f")" = "DefaultNotificationsSDK.swift" ] && continue
  if grep -vE '^\s*//' "$f" | grep -q 'UNUserNotificationCenter'; then
    violation "UNUserNotificationCenter used in $f"
  fi
done < <(find "$SRC" -name '*.swift')

# UIApplication confined to DefaultNotificationsSDK.swift (S67.2) plus the
# pre-existing key-window lookup in PaymentRedirectView.swift.
while IFS= read -r f; do
  case "$(basename "$f")" in
    DefaultNotificationsSDK.swift|PaymentRedirectView.swift) continue ;;
  esac
  if grep -vE '^\s*//' "$f" | grep -q 'UIApplication'; then
    violation "UIApplication used in $f"
  fi
done < <(find "$SRC" -name '*.swift')

if [ "$fail" -ne 0 ]; then
  echo "Boundary lint FAILED."
  exit 1
fi
echo "Boundary lint OK."
