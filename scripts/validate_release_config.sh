#!/bin/bash
set -u

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <IntegrationConfig.plist> <bundle-identifier>" >&2
  exit 64
fi

CONFIG_PATH="$1"
ACTUAL_BUNDLE_ID="$2"
ERRORS=0

fail() {
  echo "release config error: $1" >&2
  ERRORS=$((ERRORS + 1))
}

if [[ ! -f "$CONFIG_PATH" ]]; then
  fail "configuration file not found: $CONFIG_PATH"
  exit 1
fi

if ! plutil -lint "$CONFIG_PATH" >/dev/null 2>&1; then
  fail "configuration is not a valid property list: $CONFIG_PATH"
  exit 1
fi

read_value() {
  local value
  if value="$(plutil -extract "$1" raw -o - "$CONFIG_PATH" 2>/dev/null)"; then
    printf '%s' "$value"
  fi
}

required_keys=(
  CoastIntegrationMode
  CoastExpectedBundleIdentifier
  CoastPrimaryHost
  CoastPrivacyURL
  CoastTermsURL
  CoastAppStoreID
)

for key in "${required_keys[@]}"; do
  value="$(read_value "$key")"
  if [[ -z "${value//[[:space:]]/}" ]]; then
    fail "$key is missing or empty"
  fi
done

mode="$(read_value CoastIntegrationMode)"
if [[ "$mode" != "release" ]]; then
  fail "CoastIntegrationMode must be release, got '${mode:-empty}'"
fi

expected_bundle_id="$(read_value CoastExpectedBundleIdentifier)"
if [[ -z "$ACTUAL_BUNDLE_ID" ]]; then
  fail "actual bundle identifier is empty"
elif [[ "$expected_bundle_id" != "$ACTUAL_BUNDLE_ID" ]]; then
  fail "bundle identifier mismatch: config='$expected_bundle_id' build='$ACTUAL_BUNDLE_ID'"
fi

if [[ "$ACTUAL_BUNDLE_ID" == test.duckegg.ios || "$ACTUAL_BUNDLE_ID" == *.test ]]; then
  fail "test bundle identifier cannot be used for release: $ACTUAL_BUNDLE_ID"
fi

app_store_id="$(read_value CoastAppStoreID)"
if [[ -n "$app_store_id" && ! "$app_store_id" =~ ^[0-9]{6,}$ ]]; then
  fail "CoastAppStoreID must contain only digits"
fi

url_keys=(
  CoastPrimaryHost
  CoastPrivacyURL
  CoastTermsURL
)

for key in "${url_keys[@]}"; do
  value="$(read_value "$key")"
  [[ -z "$value" ]] && continue
  if [[ ! "$value" =~ ^https://[^/[:space:]]+(/[^[:space:]]*)?$ ]]; then
    fail "$key must be an absolute HTTPS URL"
    continue
  fi
  host="${value#https://}"
  host="${host%%/*}"
  host="${host%%:*}"
  normalized_host="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
  if [[ "$normalized_host" == test-* || "$normalized_host" == *.*test-* ||
        "$normalized_host" == localhost || "$normalized_host" == *.localhost ||
        "$normalized_host" == *.test || "$normalized_host" == 127.* ||
        "$normalized_host" == 0.0.0.0 ]]; then
    fail "$key contains a test or local host: $host"
  fi
done

if [[ $ERRORS -ne 0 ]]; then
  echo "release configuration rejected with $ERRORS error(s)" >&2
  exit 1
fi

echo "release configuration valid for $ACTUAL_BUNDLE_ID"
