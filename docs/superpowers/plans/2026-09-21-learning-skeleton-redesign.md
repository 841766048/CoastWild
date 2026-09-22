# Learning Skeleton Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Replace the three coarse learning placeholders with content-shaped HF-V1 skeleton screens matching the approved high-fidelity design.

**Architecture:** Add one reusable UIKit skeleton view that owns palette, shimmer, line shapes, illustration contours, and the three layouts. Existing controllers continue to own request state and only choose the appropriate layout.

**Tech Stack:** Swift 5, UIKit, Core Animation, SkeletonView 1.30.4, XCTest/XCUITest, iOS 17+

## Global Constraints

- Keep the approved warm white, sand, gray-green, and teal HF-V1 palette.
- Use list, Web detail, and native detail layouts that predict final content geometry.
- Reduce Motion uses a static skeleton.
- Preserve learning caching, scroll restoration, retry behavior, and accessibility identifiers.
- Decorative contour art remains hidden from VoiceOver.

---

### Task 1: Reusable content-aware skeleton component

**Files:**
- Create: `CoastWild/UI/LearningSkeletonView.swift`
- Modify: `CoastWild.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `LearningSkeletonView(style: LearningSkeletonStyle)` and `startAnimating()` / `stopAnimating()`.

- [x] Add `LearningSkeletonStyle` cases for `list`, `webDetail`, and `nativeDetail`.
- [x] Build reusable warm-tone line, pill, image, avatar, card, and button placeholders.
- [x] Draw low-opacity wave, ridge, and surfboard contours with `CAShapeLayer`.
- [x] Apply one restrained SkeletonView gradient and a static Reduce Motion fallback.
- [x] Expose stable root accessibility identifiers through the controllers.

### Task 2: Integrate the three states

**Files:**
- Modify: `CoastWild/UI/LearnController.swift`
- Modify: `CoastWild/UI/LearningWebController.swift`

**Interfaces:**
- Consumes: `LearningSkeletonView`.

- [x] Replace the list's single gray block with `.list` and preserve caching behavior.
- [x] Replace the Web placeholder with `.webDetail` and keep retry rendering.
- [x] Replace the native detail placeholder with `.nativeDetail`.
- [x] Stop animations before removing or hiding each placeholder.

### Task 3: Regression verification

**Files:**
- Modify: `UITests/CoastWildUITests.swift`

- [x] Assert representative skeleton child identifiers for all three layouts.
- [x] Verify returning to Learning still preserves the loaded list and scroll position.
- [x] Run `swift test`, focused learning UI tests, full workspace UI tests, build, and `git diff --check`.

