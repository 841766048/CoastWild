# Native coins UI implementation / verification

Branch: codex/native-coin-learning. User approved local wallet on 2026-09-23.

## Implemented

- Shared environment wallet and coordinator fulfillment for native and existing JS purchase pipeline.
- StoreKit localized product price; native SKU 1coins_19 credits100; trusted local guide coastal-camping costs30.
- Native Learn catalog, original free library entry, topic preview, insufficient/confirm sheets, purchase/progress/success, wallet activity and four-chapter reader.
- Explicit confirmation after recharge, duplicate unlock protection, persisted ownership and balance.
- Price load retry, payment cancellation, verification retry without a second payment, approval-pending presentation.
- Debug-only deterministic store/server require --ui-testing and --native-coins-test; release uses StoreKit and IntegrationPurchaseServer, never test credit.
- Local wallet intentionally device-wide for this installation; logout does not switch it. No cross-device/reinstall promise. Separate from ordinary trip/journal clearing.

## Verification evidence

- Baseline swift test:266 passed.
- UI RED: native-coins-red.xcresult failed at NativeCoinUITests.swift:18, missing coins.guide.coastal-camping entry before UI implementation.
- Core final swift test:283 passed,0 failures; /tmp/coast-coins-final-core.log.
- UI first GREEN:3 passed,0 failures; build/native-coins-green-1.xcresult.
- Extended native tests:6 passed,0 failures; build/native-coins-green-3.xcresult. Covers100→70, four chapters, relaunch, cancellation, free library, unavailable price, preview gate and verification retry.
- Existing free library regression initially failed because iOS26 replaces share close button with PopoverDismissRegion. Inspected screenshot + AX hierarchy; test now handles both system presentations.
- Free library regression retest passed: build/native-coins-free-regression.xcresult.
- Combined UI run:7 passed,0 failures; build/native-coins-final.xcresult.
- iPhone SE (3rd generation), iOS17.2: purchase/unlock/read/relaunch loop passed; build/native-coins-small-screen.xcresult.
- Final core rerun:283 passed,0 failures; /tmp/coins-core-handoff.log.
- Release simulator build passed with signing disabled; /tmp/coins-release.log. DEBUG test-double declarations are excluded in Release; no NativeCoinTestStore/Server symbols found in the built binary.
- Recovery RED:2 expected failures reproduced credited-before-finish recovery and terminal verification rejection; build/native-coins-recovery-red.xcresult. Recovery fix verification recorded separately.
- Handoff run:8 of9 passed in build/native-coins-handoff.xcresult; remaining failure was a test querying a system alert instead of the app's custom dialog. Corrected selector; both recovery tests then passed in build/native-coins-recovery-green.xcresult. Thus all9 UI cases pass across these runs; no all9-green combined run is claimed.
- Actual nine-screen gallery: docs/screenshots/native-coins/实现截图.md. Wallet decoration was corrected to size from content instead of image intrinsic height.

## Visual specification notes

UIKit renders all controls and text. CoinArtwork samples only photo/illustration regions from approved design source atlases; it does not display flattened UI screenshots as interactive pages.
One consistent topic photograph is used across detail, preview and reading as approved in design overview. Existing free materials remain unchanged behind the free-library entry.

Production differences from concept copy are deliberate: real starting balance0, StoreKit localized price, contextual Back to guide, removal of Preview only, and on-device retention wording. Recovered transactions do not display today's price as an asserted historic paid price. iOS system bars/sheets adapt to OS version and safe areas; exact screenshot equivalence across OS chrome is not claimed.

## Not verified by deterministic tests

Real Apple sandbox authentication/payment and live recharge create/verify for this SKU require an end-to-end sandbox run. UI tests prove app-side behavior with controlled store/server doubles, not live payment success. No real purchase was performed in this implementation run.
No backend balance, debit, cross-device sync, refund reversal or reinstall recovery was added. Local wallet can be lost if app data is removed and is not tamper-proof like a server ledger.
