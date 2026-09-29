# Temporarily disable authenticated Web entry

**Status: reverted by user request on 2026-09-24.** The temporary switch and production bypass have been removed. Authenticated startup again opens the existing business Web route using its configured/strategy URL. The native-only branch now applies solely to the existing UI-test fixture. The old test was replaced with manual-login and automatic-login Web-container regression coverage; unrelated Firebase and private-photo work remains intact. Below is the historical implementation record, not the current behavior.

**Goal:** After successful manual or automatic login, show the native tabs. Preserve Web and bridge implementation for restoration.

**Architecture:** Add `BusinessWebEntry.isEnabled = false`, a local build-wide switch, independent of server strategy or user identity. Check it before building Web bootstrap or validating Web URLs. Keep account activation and attribution unchanged. Legal and learning Web views remain available.

**Tech Stack:** UIKit, Swift, XCTest.

## Steps

- [x] Add regression assertion `XCTAssertFalse(BusinessWebEntry.isEnabled)` to `Tests/BusinessWebEntryTests.swift`; run `swift test --filter BusinessWebEntryTests` to demonstrate missing switch.
- [x] Add the switch to `CoastWild/Core/BusinessWebEntry.swift`; move Web-only initialization inside the enabled branch in `CoastWild/App/AppDelegate.swift`.
- [x] Run `swift test` and simulator `xcodebuild` through `CoastWild.xcworkspace`.

## Verification

Core tests: 252 executed, 1 skipped, 0 failures. Simulator build succeeded. Added UI regression `testDisabledWebEntryUsesNativeTabsAfterManualAndAutomaticLogin`, explicitly requesting the former Web route to avoid the existing native UI-test shortcut; manual login and relaunch automatic login both displayed native tabs, with no business Web view. UI test passed. Test authentication uses the existing fake API; no claim of live backend login verification.

## Constraints and restoration

Restoration verification (2026-09-24): the replacement Web-entry UI test failed before removal and passed after removal for both manual and automatic login, also confirming hidden navigation and no native tabs. Full core suite: 259 tests, 1 skipped, 0 failures. The signed simulator test build passed. Test login uses the fake API; this verifies routing, not live H5 service availability.

Do not remove Web/JS code, change signing, alter Firebase, bypass login or privacy consent, or commit unrelated working-tree changes. Restore by setting the switch to `true` and updating the regression expectation. The current false value applies equally to every user and build configuration; remote configuration cannot override it.
