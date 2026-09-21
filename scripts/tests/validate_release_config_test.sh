#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VALIDATOR="$ROOT/scripts/validate_release_config.sh"
FIXTURES="$ROOT/scripts/tests/fixtures/release-config"

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

echo "release config validator contract tests passed"
