# Coast & Wild UIKit Implementation Plan

> Execute with subagent-driven-development; UIKit implementation follows the approved HF-v1.2 design.

**Goal:** Build and run the native iPhone app covering discovery, learning, trips, journals, preferences and login gating.
**Architecture:** UIKit controllers and native navigation; Codable value models; atomic per-account local ledgers; Keychain demo credentials. Resource-backed bilingual catalog shared with approved H5.
**Tech Stack:** Swift 5, UIKit, iOS 17+, PhotosUI, Security, CryptoKit, XCTest, XcodeGen. No third-party runtime dependencies.

## Global Constraints
- Swift + UIKit only; no SwiftUI or web views.
- HF-v1.2 colors, original 11 images and SVG icons; support English and Simplified Chinese.
- Login required before business screens. Local demo credentials and password recovery are explicitly labeled; no real email claim.
- Language, region and units persist independently. Account ledgers isolated. Failed saves preserve editor state.
- Field limits, duplicate trip activities, drafts, deletion semantics and export follow ../docs/字段与交互契约-v1.md.
- Preserve original artwork and H5 source. Native app lives exclusively in ios/.

## Tasks
- [ ] 1. Core: Tests first for validation, account isolation, duplicate activities, journal drafts, persistence and completion idempotence; implement in Core/ with Foundation and XCTest via Swift Package. See core-brief.md for exact API contract.
- [ ] 2. App/UI: XcodeGen app target, UIKit shared typography/components, bundled images/catalog, auth onboarding root and tab navigation. Match Figma inspected on desktop. Check with simulator build and login navigation.
- [ ] 3. Features: discovery search/filter/details/bookmarks, lesson progression, trip CRUD/activity ordering, journal photos/drafts/share, account/preferences/export/clear. Map all business screen IDs and contextual states.
- [ ] 4. Verification: core tests; iOS simulator build; native interaction smoke test; compare screenshots with Figma. Review and fix material issues. Document actual coverage and production-service limitations.
