# Trip Cover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional, persisted trip cover selected from the system photo library and render it throughout the trip UI with the existing camp image as fallback.

**Architecture:** Store an optional account-local filename on `CoastTrip`, reuse `CoastEnvironment` photo storage, and extend cleanup to include trip references. `TripEditorController` owns pending cover state and the single-image picker; trip list/detail receive a resolved `UIImage` so rendering remains independent of storage.

**Tech Stack:** Swift 5, UIKit, PhotosUI, Codable JSON store, XCTest/XCUITest, iOS 17+

## Global Constraints

- Preserve Swift + UIKit and CocoaPods dependencies.
- Match the approved HF-v1 optional-cover board.
- Cover selection is optional and limited to one image.
- `camp` remains the fallback cover.
- Keep existing account isolation and atomic local persistence.

---

### Task 1: Cover persistence contract

**Files:**
- Modify: `CoastWild/Core/Models.swift`
- Modify: `Tests/CoastWildCoreTests.swift`

**Interfaces:**
- Produces: `CoastTrip.coverPhoto: String?` and initializer argument `coverPhoto: String? = nil`.

- [x] Add tests proving default `nil`, round-trip persistence, and legacy JSON decoding without the field.
- [x] Run `swift test` and verify the new assertions fail because the property is absent.
- [x] Add the optional Codable property and initializer argument.
- [x] Run `swift test` and verify all Core tests pass.

### Task 2: Safe photo lifecycle

**Files:**
- Modify: `CoastWild/App/AppDelegate.swift`
- Modify: `Tests/CoastWildCoreTests.swift` where model persistence is covered.

**Interfaces:**
- Consumes: `CoastTrip.coverPhoto`.
- Produces: `cleanUnusedPhotos()` retaining both journal photos and trip covers.

- [x] Cover the reference set through model/store tests and inspect cleanup behavior in the UI flow.
- [x] Change the used filename set to include every non-nil trip cover.
- [x] Verify the lifecycle rules in the controller: cancel preserves the stored original, while save/removal/deletion clean unreferenced files.

### Task 3: HF-v1 editor and system picker

**Files:**
- Modify: `CoastWild/UI/TripsController.swift`
- Modify: `UITests/CoastWildUITests.swift`

**Interfaces:**
- Consumes: `env.photo(_:)`, `env.photoURL(_:)`, `trip.coverPhoto`.
- Produces: accessible controls `trip.cover.add`, `trip.cover.remove`, `trip.cover.preview`.

- [x] Extend UI tests to require the optional cover card and default state.
- [x] Run the focused UI test and verify it fails because the controls are absent.
- [x] Add the 2:1 preview, default badge, localized helper copy, add/change button, remove button, and single-image `PHPickerViewController` flow.
- [x] Include cover changes in cancel detection; clean pending files after cancel and obsolete files after save.
- [x] Run the focused UI test and inspect a screenshot against the approved board.

### Task 4: List and detail cover rendering

**Files:**
- Modify: `CoastWild/UI/TripsController.swift`
- Modify: `CoastWild/UI/Components.swift` only if a shared image overload is needed.
- Modify: `UITests/CoastWildUITests.swift`

**Interfaces:**
- Consumes: resolved cover image `trip.coverPhoto.flatMap(env.photo) ?? UIImage(named: "camp")`.

- [x] Add UI assertions for fallback cover identifiers in list and detail.
- [x] Update hero card, compact row, and trip detail to use the resolved image with `scaleAspectFill` and existing corner radii.
- [x] Run all Core and UI tests, build the workspace, capture Chinese editor/list screenshots, and record results.
