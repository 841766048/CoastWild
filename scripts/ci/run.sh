#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$TASK_ROOT"
mkdir -p build/codemagic

case "${1:-}" in
  dependencies)
    # Use the committed project: regeneration could replace local signing settings.
    [[ "$(pod --version)" == "1.16.2" ]] || { echo "CocoaPods 1.16.2 is required" >&2; exit 1; }
    pod install --deployment
    # Fail early if dependency integration reintroduces a duplicate static framework.
    python3 scripts/ci/tests/test_pods_linking.py
    git diff --exit-code -- Podfile.lock
    python3 -m venv build/ci-venv
    build/ci-venv/bin/python -m pip install -r scripts/ci/requirements.txt
    ;;
  checks)
    build/ci-venv/bin/python -m unittest discover -s scripts/ci/tests -v 2>&1 | tee build/codemagic/ci-tests.log
    bash scripts/tests/validate_release_config_test.sh 2>&1 | tee build/codemagic/release-config-tests.log
    swift test 2>&1 | tee build/codemagic/core-tests.log
    ;;
  simulator)
    xcodebuild -workspace CoastWild.xcworkspace -scheme CoastWild \
      -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath build/codemagic/DerivedData \
      -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build \
      2>&1 | tee build/codemagic/simulator-build.log
    ;;
  archive)
    [[ "${CM_BRANCH:-}" == codex/native-coin-learning && "${CM_TRIGGER_SOURCE:-}" == api && "${CM_PULL_REQUEST:-false}" != true ]] || {
      echo "Archive requires a manual Codemagic codex/native-coin-learning build" >&2; exit 1;
    }
    [[ "${COAST_BUILD_NUMBER:-}" =~ ^[1-9][0-9]{3}$ ]] || {
      echo "Run the preflight step before archiving" >&2; exit 1;
    }
    xcode-project use-profiles --project CoastWild.xcodeproj \
      --export-options-plist build/codemagic/export_options.plist
    python3 scripts/ci/ci_support.py export build/codemagic/export_options.plist
    xcodebuild -showBuildSettings -json -workspace CoastWild.xcworkspace -scheme CoastWild \
      -configuration Release -sdk iphoneos -disableAutomaticPackageResolution \
      > build/codemagic/signing-settings.json
    python3 scripts/ci/ci_support.py signing build/codemagic/signing-settings.json
    xcode-project build-ipa --workspace CoastWild.xcworkspace --scheme CoastWild --config Release \
      --export-options-plist build/codemagic/export_options.plist \
      --archive-directory build/ios/xcarchive --ipa-directory build/ios/ipa \
      --archive-xcargs="CURRENT_PROJECT_VERSION=$COAST_BUILD_NUMBER" \
      2>&1 | tee build/codemagic/archive.log
    ;;
  *) echo "usage: $0 dependencies|checks|simulator|archive" >&2; exit 64 ;;
esac
