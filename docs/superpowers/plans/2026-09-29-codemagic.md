# Codemagic configuration plan

**Goal:** Configure identical CI files on main and codex/native-uikit without touching V2. Development pushes run checks and simulator build; main manually exports a signed IPA using the current test backend, with no store publishing.

**Architecture:** Use the committed Xcode project/workspace, locked CocoaPods and Swift Package dependencies, and Codemagic-managed signing assets. Do not regenerate the project in CI. Cloud-only signing settings are applied by Codemagic CLI. Credentials never enter Git.

**Stack:** Codemagic YAML, bash, Python standard-library validation/tests, existing Swift tests.

## Constraints

- Preserve local project signing, app code, Firebase config and second-release branch.
- Keep Bundle ID com.huankecontact.test and existing development backend. Label signed workflow as testing only; no automatic store upload or review submission.
- No certificate generation/revocation, real payment, cloud data mutations or cloud builds without credentials/account setup.
- Pin Xcode 26.1.1 and CocoaPods 1.16.2; use pod install --deployment and resolved Swift Package versions, not update.
- Commit/push CI configuration to both requested GitHub branches after verification; no force push.

## Tasks

- [x] Correct scripts/validate_release_config.sh and fixtures/tests to current V1 fields and runtime mode release (not production); preserve strict HTTPS/test-host/bundle validation. Tests demonstrate failure before fix; never require removed Web/Adjust fields.
- [x] Add codemagic.yaml with dev-checks and main-ipa workflows. Dev push branch exact codex/native-uikit; main no automatic triggers, branch/manual runtime guard. No secrets on dev workflow. Main ios_signing app_store + matching bundle ID, user-configured signing identities required.
- [x] Add scripts/ci helpers for branch/environment preflight, dependency installation, Swift+script tests, simulator compile and archive/export. Use PROJECT_BUILD_NUMBER for monotonic build numbering with a documented offset; fail on missing/invalid numbers. Archive via Codemagic CLI and verify signing choices before building. Test helper validation with subprocess/unit tests and YAML workflow contracts.
- [x] Document dashboard setup, App Store certificate/profile requirements, first manual run, test-backend caveat, no sideloading for App Store IPA, and future explicit TestFlight configuration.
- [x] Validate YAML/shell scripts/helpers, run core tests and a relevant existing-dependency local simulator build; clearly report unverified cloud signing/build. Review changes and remote tips. V2 unchanged.

## Verification and handoff

Official YAML schema, 12 CI tests, release-config shell tests, 186 Swift tests, 15 content-tool tests and local simulator compilation passed. The archive guard correctly rejects a local/non-main invocation.

Delivery: commit only task paths and atomically push the same commit to main/native-uikit, without force. Verify remote hashes after delivery.

Pending external setup: user has added the repository to Codemagic but has not configured signing. Upload matching Apple Distribution credentials and a manually created App Store profile before the first main-ipa run. Clean-machine dependency installation and cloud signing/export remain unverified.
