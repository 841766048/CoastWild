#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bundle check || bundle install
xcodegen generate
bundle exec pod install
