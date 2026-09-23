# V1 first-party IAP removal report

Task 1 is implemented in `ios/.worktrees/v1-no-iap` on `codex/native-uikit`. No commits, branch operations, pushes or Xcode builds were performed by this task agent.

## Changes

Removed the StoreKit adapter, product catalog, purchase coordinator/order mapping/logging/server, IAP bridge handler, payment API endpoints/DTOs, purchase attribution event and token configuration. Removed transaction observation and restore wiring from app initialization and account UI. Removed purchase callbacks and all seven former payment topics; routing them now raises the existing `BridgeError.unknownTopic`.

Kept login/session handling, configuration loading, ordinary Adjust attribution, free native learning, general JS navigation/settings/language/logging/lifecycle features. The App Store review topic now opens the HTTPS write-review URL using the bootstrap app ID without a StoreKit import. InternalWebController required no edits: it only registers its existing close-web contract and never contained the purchase bridge.

Updated English/Chinese privacy/terms and account deletion text to remove payment/subscription references. Retained disclosure of the existing simulated account deletion behavior. Retained log redaction for arbitrary sensitive fields, including receipt/order/JWS names.

## RED/GREEN evidence

- Baseline supplied by root: 266 Swift tests passed, `/tmp/coast-v1-baseline.log`.
- Added `Tests/VersionOneBoundaryTests.swift` before production edits. Corrected its initial missing router handler constructor argument before evaluating RED.
- RED: `swift test --filter VersionOneBoundaryTests`, 2026-09-23 16:38:08 local: 2 tests, 63 expected assertion failures, 0 unexpected failures. Log: `/tmp/coast-v1-boundary-red.log`.
- Tests assert all seven former topics are absent from `BridgeTopic.allCases`, resolve to nil, and are rejected as unknown without dispatch. Static checks derive the source root from `#filePath` and scan only first-party production Swift/plist/strings/HTML.
- The first complete suite after removal surfaced four stale legal expectations for payments/subscriptions. Updated only those expectations; all remaining legal disclosures stay tested.
- GREEN: `swift test`, exit 0, 2026-09-23 16:41:22 local: 240 tests, 0 failures. Log: `/tmp/coast-v1-green.log`. Count is baseline minus 28 purchase-only tests plus 2 V1 boundary tests.
- `xcodegen generate` completed successfully and regenerated `CoastWild.xcodeproj/project.pbxproj`.
- `git diff --check` completed without findings.
- UI assertion updated in `CoastWildUITests/testAccountActionsAreDistinctAndDeletionFailureCanRetry`: logout and delete still exist, restore entry and subscription warning do not. Root owns execution; this task does not claim an Xcode/UI pass.
- Existing free-learning UI regression to run: `CoastWildUITests/testLearningLibraryLoadsWebAndNativeDetails`.

## Self-review and limitations

Independent root review found XcodeGen removed the committed app target signing team because project.yml only had an empty project-level default. Added the existing app target team `2FXAU7VW4X` to target settings in project.yml. After root's active UI run finished, ran `xcodegen generate && bundle exec pod install` successfully (4 dependencies, 12 pods). Verified both Debug and Release app target configurations retain `DEVELOPMENT_TEAM = 2FXAU7VW4X` with their CocoaPods base configurations. Podfile.lock and Gemfile.lock are unchanged; `git diff --check` passed again.

Root's initial UI execution passed account/profile and persisted-session cases. The free-learning case successfully opened the image share sheet but failed tapping the absent `header.closeButton` on iOS 26.1 (`/tmp/coast-v1-ui.log`, UITests line 358). Compared the existing helper against feature commit `1e52224` and ported only its conditional close-button/`PopoverDismissRegion` fallback, retaining the assertion that the sheet disappears. No coin-library entry step or product behavior was ported. Root owns the rerun of free-learning UI and Release validation after this test-harness compatibility fix.

Reviewed all mixed-file production diffs and changed tests. Non-payment request assertions remain: strategy, OAuth and attribution requests still use the derived key and expected parameters. ATT/SDK startup and attribution submission tests remain. Deleted only seven purchase-only production files and three purchase-only test files.

A case-insensitive production scan for purchase, StoreKit, recharge, entitlement, IAP, receipt, subscription and Chinese payment terms found only `receipt` in `BridgeNativeLog.isSensitiveKey`, intentionally retained for sanitization. Filename scan found no purchase/StoreKit/IAP/entitlement production files. Generated project scan found no purchase/StoreKit/IAP/recharge references. Broader restore search still finds unrelated device identity/session recovery and scroll-offset restoration; those remain.

Ordinary Adjust attribution is deliberately retained. Root separately found generic purchase/verification classes inside the vendored Adjust SDK; these are third-party internals, not first-party callable purchase integration. This report does not claim that the final binary has zero third-party purchase-related symbols. Root owns CocoaPods reintegration, linked-binary inspection, Release simulator build, UI verification, independent review and commit.

No source edits outside the V1 worktree. Original feature checkout and its staged privacy asset were not touched.

## Changed tracked files

```text
M	CoastWild.xcodeproj/project.pbxproj
M	CoastWild/App/AppDelegate.swift
M	CoastWild/App/AttributionAdapters.swift
D	CoastWild/App/StoreKit2PurchaseStore.swift
M	CoastWild/Core/AttributionCoordinator.swift
M	CoastWild/Core/BridgeMessage.swift
M	CoastWild/Core/BridgeRouter.swift
M	CoastWild/Core/BusinessBridgeAction.swift
D	CoastWild/Core/IAPBridgeHandler.swift
M	CoastWild/Core/IntegrationAPIClient.swift
M	CoastWild/Core/IntegrationDTOs.swift
M	CoastWild/Core/IntegrationEndpointPaths.swift
M	CoastWild/Core/IntegrationEnvironment.swift
M	CoastWild/Core/IntegrationEnvironmentLoader.swift
D	CoastWild/Core/IntegrationPurchaseServer.swift
M	CoastWild/Core/IntegrationRuntimeConfiguration.swift
M	CoastWild/Core/JavaScriptCallbackEncoder.swift
D	CoastWild/Core/ProductCatalog.swift
D	CoastWild/Core/PurchaseCoordinator.swift
D	CoastWild/Core/PurchaseLog.swift
D	CoastWild/Core/PurchaseOrderMappingStore.swift
M	CoastWild/Resources/IntegrationConfig.plist
M	CoastWild/Resources/Legal/privacy-en.html
M	CoastWild/Resources/Legal/privacy-zh-Hans.html
M	CoastWild/Resources/Legal/terms-en.html
M	CoastWild/Resources/Legal/terms-zh-Hans.html
M	CoastWild/UI/BusinessWebController.swift
M	CoastWild/UI/ProfileController.swift
M	Tests/AttributionTests.swift
M	Tests/BridgeTests.swift
M	Tests/BusinessBridgeActionTests.swift
M	Tests/BusinessBridgeApplicationTests.swift
D	Tests/IAPBridgeHandlerTests.swift
M	Tests/IntegrationEnvironmentTests.swift
M	Tests/IntegrationNetworkTests.swift
M	Tests/IntegrationRuntimeConfigurationTests.swift
M	Tests/IntegrationRuntimeEpochTests.swift
M	Tests/LegalDocumentTests.swift
D	Tests/PurchaseOrderMappingStoreTests.swift
D	Tests/PurchaseTests.swift
M	UITests/CoastWildUITests.swift
```

New task files: `Tests/VersionOneBoundaryTests.swift` and this report. Root owns the shared implementation plan and release strategy documents.

Additional review fix: `project.yml` now explicitly preserves the app target's existing signing team.

## Root verification

- Independent source/config review approved; signing-team regression was fixed and re-reviewed.
- Fresh core suite:240 passed,0 failures (`/tmp/coast-v1-core-final.log`).
- Final Release simulator build after the fixture/config changes passed (`/tmp/coast-v1-release-handoff.log`); code signing disabled for simulator verification. Physical-device signing was not exercised.
- Profile removal and free-learning UI passed in `build/v1-validation-final.xcresult`. The third test missed a transient fixture screen; its AX snapshot already showed Explore, not login.
- After extending only the explicit slow-recovery test fixture window, automatic-session UI passed with every assertion retained (`build/v1-session-stable.xcresult`,16.62 seconds).
- First-party production source scan leaves only `receipt` in sensitive-log redaction vocabulary. Release binary scan found no StoreKit load command, first-party purchase coordinator/adapter/bridge symbols, former purchase JS names or recharge endpoint strings. Generic Adjust SDK purchase classes are not claimed absent.
- UI compatibility and test-fixture adjustments were independently reviewed. No live payment is performed by these checks.

## UI timing follow-up

Root's final profile and free-learning runs passed, including both share-sheet dismissal paths supported by the helper. The persisted-session case intermittently failed observing `startup.recovery`: the UI-only fake API delayed configuration for 2 seconds, while XCTest launch/idle synchronization and first polling consumed its observation window. First AX check occurred 3.18 seconds after launch in the passing run versus 3.41 seconds in the failing run. Root exported `build/v1-failure-inspection/66D7FA21-3F50-4AB5-8129-CA82AAEFCDC4.txt`; its snapshot already showed Explore, confirming successful restoration rather than an unexpected login screen.

With root approval, changed only the existing `--ui-testing-slow-recovery` fixture delay in `CoastWild/App/UITestRemoteAuthenticationAPI.swift` from 2 to 5 seconds, documenting XCTest synchronization. All UI assertions and normal API behavior remain unchanged. Root owns final UI rerun. This is a non-IAP test reliability change that root will also preserve in V2, explicitly exempted from original V2 source-tree identity comparison.
