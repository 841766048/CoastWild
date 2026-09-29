#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VALIDATOR="$ROOT/scripts/validate_release_config.sh"
FIXTURES="$ROOT/scripts/tests/fixtures/release-config"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

expect_success() {
  local fixture="$1"
  if ! "$VALIDATOR" "$FIXTURES/$fixture" "com.example.coastwild" >/dev/null; then
    echo "expected success: $fixture" >&2
    exit 1
  fi
}

expect_failure() {
  local fixture="$1"
  local bundle_id="${2:-com.example.coastwild}"
  if "$VALIDATOR" "$FIXTURES/$fixture" "$bundle_id" >/dev/null 2>&1; then
    echo "expected failure: $fixture" >&2
    exit 1
  fi
}

expect_success valid.plist
expect_failure empty-value.plist
expect_failure test-host.plist
expect_failure insecure-url.plist
expect_failure mock-value.plist
expect_failure valid.plist com.example.other

# Mutations start with a complete valid V1 configuration to isolate each rule.
expect_invalid_value() {
  local key="$1" value="$2" diagnostic="$3"
  local bundle_id="${4:-com.example.coastwild}"
  cp "$FIXTURES/valid.plist" "$TEMP_DIR/config.plist"
  plutil -replace "$key" -string "$value" "$TEMP_DIR/config.plist"
  if "$VALIDATOR" "$TEMP_DIR/config.plist" "$bundle_id" >"$TEMP_DIR/output" 2>&1; then
    echo "expected rejection: $key=$value" >&2
    exit 1
  fi
  if ! grep -Fq "$diagnostic" "$TEMP_DIR/output"; then
    echo "missing diagnostic '$diagnostic' for $key=$value" >&2
    cat "$TEMP_DIR/output" >&2
    exit 1
  fi
}

expect_invalid_value CoastIntegrationMode development 'must be release'
expect_invalid_value CoastIntegrationMode production 'must be release'
expect_invalid_value CoastExpectedBundleIdentifier test.duckegg.ios 'test bundle identifier' test.duckegg.ios
expect_invalid_value CoastExpectedBundleIdentifier com.example.coastwild.test 'test bundle identifier' com.example.coastwild.test
expect_invalid_value CoastAppStoreID 123abc 'only digits'
for key in CoastIntegrationMode CoastExpectedBundleIdentifier CoastPrimaryHost CoastPrivacyURL CoastTermsURL CoastAppStoreID; do
  cp "$FIXTURES/valid.plist" "$TEMP_DIR/config.plist"
  plutil -remove "$key" "$TEMP_DIR/config.plist"
  if "$VALIDATOR" "$TEMP_DIR/config.plist" com.example.coastwild >"$TEMP_DIR/output" 2>&1; then
    echo "expected rejection for missing key: $key" >&2
    exit 1
  fi
  grep -Fq "$key is missing or empty" "$TEMP_DIR/output"
done
for key in CoastPrimaryHost CoastPrivacyURL CoastTermsURL; do
  expect_invalid_value "$key" '   ' "$key is missing or empty"
  expect_invalid_value "$key" http://example.com "$key must be an absolute HTTPS URL"
  for host in test-app.bigegg.work test-h5.bigegg.work test-im.bigegg.work test-log.bigegg.work localhost sub.localhost api.test 127.0.0.1 0.0.0.0; do
    expect_invalid_value "$key" "https://$host" "$key contains a test or local host"
  done
done

echo "release config validator contract tests passed"
