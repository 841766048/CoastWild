# English-only presentation and icon-only navigation

> Execute with subagent-driven-development and independent review. User approved the design and both branches; do not commit, merge or push.

**Goal:** Both native-uikit and native-coin-learning show English app-owned UI and arrow-only back buttons.

**Architecture:** Normalize persisted presentation language to English, preserve user text and multilingual wire schemas, remove Chinese choices/bundled legal localization, and centralize back-button display in the existing navigation controller.

**Tech Stack:** Swift, UIKit, XCTest, XcodeGen, existing dependencies.

## Global Constraints

- Preserve all pre-existing dirty changes in both worktrees.
- Do not delete or translate user-entered notes, titles or photos.
- Preserve V1/V2 feature separation; V2 Web, Bridge, attribution and purchases remain.
- Only app-owned presentation is English-only; do not corrupt remote API schemas or delete cloud data. External H5 content is server-owned.
- No dependency upgrades, deployments, commits, merges or pushes.

## Task 1 — Both branches: implementation and core regression

Files: CoastWild/Core/CoastStore.swift, LegalDocument.swift; App/AppDelegate.swift; UI/ProfileController.swift, Components.swift; Resources/Legal/*zh-Hans*, Resources/zh-Hans.lproj; Tests/EnglishPresentationTests.swift, LegalDocumentTests.swift, CoastWildCoreTests.swift; existing UI tests that explicitly require Chinese; project.yml and generated project only as needed.

- [x] Snapshot the current files before modifying them for a task-only review diff.
- [x] Add failing tests: load a persisted zh-Hans preference and expect en while region, units and user text remain; preference updates cannot enable Chinese; legal resources/title/URL select English even for legacy zh input. Run `swift test --filter EnglishPresentationTests` in both roots and record RED.
- [x] Normalize preferences on read and write with `next.language = "en"`, persisting migration without changing unrelated fields. Make the UI language source English including fresh UI-test initialization and system date/permission presentation; remove the Chinese selector. Retain inaccessible bilingual helpers only where removing them is unrelated churn; no app-owned visible Chinese.
- [x] LegalDocument uses English local title/resource/URL. Remove bundled Chinese legal HTML and InfoPlist localization. Remove obsolete Chinese legal build keys and adjust resource inclusion safely; use XcodeGen or Swift XcodeProj, never raw pbxproj editing or Ruby.
- [x] Set `.backButtonDisplayMode = .minimal` on every navigation-stack item in the shared CoastNavigationController before pushes and replacements; remove explicit Back/previous-page-title assignments. Keep accessibility labels and existing interactive-pop behavior.
- [x] Update existing tests that deliberately expected Chinese to assert the approved English behavior; do not drop scenario coverage. Run full `swift test` once per branch (V1 with existing COAST_PUBLIC_MANIFEST).
- [x] Report exact modifications, tests and any remaining externally-owned localization limitations to `/tmp/coast-english.p30QGO/implementation-report.md`.

## Task 2 — Build, UI and review

- [x] Review task-only diff independently for both language migration and navigation behavior.
- [x] Build both workspaces with existing dependency resolution; preserve Pods integration and signing.
- [x] Run English privacy/settings/back-navigation smoke tests on independent test simulators with system Chinese and legacy language arguments where possible. Verify arrow visually; accessibility can still call it Back.
- [x] Confirm release resource lists omit app Chinese resources; V2 boundary tests still preserve Web/Bridge/Adjust/IAP.
- [x] Record results and limitations, check git diff --check and branch state, leave modifications local and uncommitted.
