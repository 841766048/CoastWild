# Learning Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 45-article bilingual learning library with Web and native detail types plus consistent simulated-network Loading states.

**Architecture:** Decode one validated lesson manifest from `catalog.json`, route entries by `detailType`, render Web articles from structured blocks into a local mobile HTML document, and keep native lessons as UIKit steps. `LearningRepository` owns request delay, cancellation, and errors; controllers only render loading, success, or retry states.

**Tech Stack:** Swift 5, UIKit, WebKit, SafariServices, async/await, CocoaPods SkeletonView, XCTest/XCUITest, iOS 17+

## Global Constraints

- Exactly 45 articles: 15 each for `surf`, `hike`, and `camp`.
- Each category has exactly 8 `web` and 7 `native` entries.
- All user-facing content contains `en` and `zh-Hans` values.
- Images are local project assets; icons are SF Symbols or existing project icons.
- Every learning list/detail read goes through `LearningRepository`.
- UI tests disable artificial delay; production simulation uses 650–1100ms.
- Existing login gate, lesson progress, visual tokens, and navigation motion remain intact.

---

### Task 1: Typed learning manifest

**Files:**
- Modify: `CoastWild/App/Catalog.swift`
- Modify: `Tests/CoastWildCoreTests.swift`

**Interfaces:**
- Produces: `CoastLessonDetailType`, `CoastLesson`, `CoastWebDetail`, `CoastNativeDetail`, `CoastWebBlock`, `CoastSourceLink`.

- [ ] Add decoding tests proving Web/native payload discrimination, bilingual requirements, icon/image fields, and legacy lesson decoding behavior.
- [ ] Run the focused tests and record the expected failure against the existing step-only model.
- [ ] Implement Codable models and `validateLearningLibrary()` with stable validation errors.
- [ ] Run focused tests and confirm they pass.

### Task 2: Forty-five curated articles

**Files:**
- Modify: `CoastWild/Resources/catalog.json`
- Modify: `Tests/CoastWildCoreTests.swift`

**Interfaces:**
- Consumes: Task 1 manifest.
- Produces: 45 complete bilingual learning entries.

- [ ] Add a test asserting 15 entries per category, 8 Web plus 7 native, unique keys, valid next-article references, nonempty bilingual content, valid HTTPS sources, and existing local image names.
- [ ] Replace the small lesson fixture with the 45-entry content matrix defined in the design spec.
- [ ] Write original bilingual summaries and instructional copy; attach authoritative source URLs without copying source prose.
- [ ] Run JSON decoding and library validation tests.

### Task 3: Repository and request state

**Files:**
- Create: `CoastWild/App/LearningRepository.swift`
- Modify: `CoastWild/App/AppDelegate.swift`
- Create: `Tests/LearningRepositoryTests.swift`

**Interfaces:**
- Produces: `LearningRepository.lessons(category:) async throws -> [CoastLesson]` and `lesson(id:) async throws -> CoastLesson`.

- [ ] Test delay injection, cancellation, missing IDs, simulated failure, and category filtering.
- [ ] Implement repository with an injected nanosecond delay provider and deterministic UI-test configuration.
- [ ] Inject one repository through `CoastEnvironment`.
- [ ] Run repository and existing environment tests.

### Task 4: Skeleton loading and learning list

**Files:**
- Modify: `Podfile`
- Modify: `Podfile.lock`
- Modify: `CoastWild/UI/LearnController.swift`
- Modify: `UITests/CoastWildUITests.swift`

**Interfaces:**
- Consumes: `LearningRepository`, SkeletonView.
- Produces: cancellable loading/success/error states for the learning list.

- [ ] Add `SkeletonView` through CocoaPods and verify workspace integration.
- [ ] Add UI coverage for visible Loading, populated cards, category switching, and retry after simulated failure.
- [ ] Replace synchronous catalog reads with one cancellable Task per selected category.
- [ ] Render skeleton cards matching final image/card geometry; use static skeletons under Reduce Motion.
- [ ] Add type icon, reading time, level, and tags to cards while preserving HF-V1 spacing.

### Task 5: Mobile Web detail

**Files:**
- Create: `CoastWild/UI/LearningWebController.swift`
- Create: `CoastWild/UI/LearningHTMLRenderer.swift`
- Modify: `CoastWild/UI/LearnController.swift`
- Modify: `UITests/CoastWildUITests.swift`

**Interfaces:**
- Produces: `LearningHTMLRenderer.render(lesson:language:) throws -> String` and `LearningWebController`.

- [ ] Test HTML escaping, localization, all block types, local image URLs, source links, viewport metadata, and HF-V1 CSS tokens.
- [ ] Build the 393pt-responsive HTML template matching the approved mobile design.
- [ ] Load the repository detail before creating the HTML and show a SkeletonView placeholder meanwhile.
- [ ] Restrict navigation to local content and open explicit HTTPS source taps in `SFSafariViewController`.
- [ ] Add UI coverage for hero, summary, diagram/checklist, sources, and continue-learning action.

### Task 6: Native detail

**Files:**
- Modify: `CoastWild/UI/LearnController.swift`
- Modify: `UITests/CoastWildUITests.swift`

**Interfaces:**
- Consumes: `CoastNativeDetail`.
- Produces: image/icon-enabled UIKit lesson steps with the existing progress contract.

- [ ] Adapt `LessonController` to load the selected lesson through the repository.
- [ ] Render each native step's image, SF Symbol icon, body, optional callout, and previous/next actions.
- [ ] Preserve `CoastStore.setProgress` semantics and completion navigation.
- [ ] Add UI coverage for Loading, forward/backward steps, reload persistence, and completion.

### Task 7: Regression and delivery

**Files:**
- Modify: `docs/native-coverage.md`
- Create: `docs/learning-library-sources.md`
- Create: `docs/learning-library-verification.md`

**Interfaces:**
- Consumes: all previous tasks.

- [ ] Document every article title, detail type, image, icon, and source organization.
- [ ] Run `pod install`, `swift test`, focused learning UI tests, full workspace UI tests, workspace build, JSON validation, and `git diff --check`.
- [ ] Record exact commands, pass counts, simulator version, and physical-device limitations.

