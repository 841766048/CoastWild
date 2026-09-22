# Learning Image Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give all 45 learning lessons a unique photographic cover and a unique HF-V1 instructional illustration.

**Architecture:** Generate five three-panel source sheets per category and style, crop them into 90 independent assets, and store each asset in its own Xcode image set. Update the existing catalog fields so UIKit and Web renderers consume the new names without controller changes.

**Tech Stack:** ImageGen, Python 3, Pillow, Xcode asset catalogs, Swift/XCTest, UIKit

## Global Constraints

- Preserve the 45 existing lesson keys and bilingual text.
- Use `learn-<key>-photo` and `learn-<key>-illustration` as stable names.
- Do not place text, logos, or watermarks inside generated images.
- Keep each output below 900 KB and the full new library below 55 MB.
- Preserve the original eight shared images.

---

### Task 1: Resource contract test

**Files:**
- Modify: `Tests/CoastWildCoreTests.swift`

- [x] Add a test requiring unique generated photo and illustration names for every lesson.
- [x] Run `swift test` and verify the test fails against the old shared image names.

### Task 2: Generate and import 90 assets

**Files:**
- Create: `CoastWild/Resources/Assets.xcassets/learn-*.imageset/Contents.json`
- Create: `CoastWild/Resources/Assets.xcassets/learn-*.imageset/*.jpg`
- Create: `CoastWild/Resources/Assets.xcassets/learn-*.imageset/*.png`

- [x] Generate 15 photographic three-panel sheets and crop them into 45 covers.
- [x] Generate 15 illustrated three-panel sheets and crop them into 45 teaching images.
- [x] Resize, compress, and import all outputs into independent image sets.
- [x] Inspect representative surf, hike, and camp results from both styles.

### Task 3: Catalog mapping

**Files:**
- Modify: `CoastWild/Resources/catalog.json`

- [x] Point every `heroImage` to its lesson photo.
- [x] Point Web image blocks and native step images to the lesson illustration.
- [x] Validate JSON and confirm all 90 asset names resolve.
- [x] Run `swift test`, `xcodebuild build`, and `git diff --check`.
