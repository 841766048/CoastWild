# HF-v1.2 content screen alignment

## Affected design screens

- EX01: 32 pt root heading with profile action, 44 pt region row, 46 pt search, 244 pt feature image, 23/14 pt feature copy, 21 pt section title, and two 155 pt image tiles.
- EX02: search/filter behavior retained in a single 48 pt search/filter row; individually sized 40 pt category pills and 161 pt bordered results use 124 × 128 images and trailing chevrons.
- EX03: 238 pt detail photo, field-note eyebrow, 32 pt title, long-form copy, 50 pt trip action, 23 pt related heading, and 114 pt related card.
- EX04: 238 pt destination photo, 32/16 pt title block, coast/walks/camp fact row, 23 pt experience group, 114 pt related cards, and source disclaimer.
- EX05: title before 238 pt detail image, three-column metrics, 23 pt detail heading, 50 pt trip action, and source disclaimer.
- LE01: 32 pt root heading with profile action, 23/14 pt introduction, 40 pt categories, 21 pt group heading, and bordered lesson cards with 180 pt first and 110 pt subsequent images.
- LE02: 13 pt progress copy, 32 pt step heading, 320 pt lesson image, 16/24 body copy, and 50 pt next/previous actions.
- LE03: centered completion hierarchy and three 50 pt follow-up actions.

Heading labels retain the shared HF-v1.2 tracking values and use the exact imported line heights (including 35.84, 27.6, 25.2, 22.1, 20.3, and 18.85 pt).
Explore and Learn category pills explicitly use the imported 14 pt regular type instead of `UIButton.Configuration`'s default title size; configured field and lesson action buttons likewise declare their 14/16 pt JSON typography.

## Preserved operations

Search text and category/duration filters, bookmarks, profile and preference navigation, add-to-trip selection/creation, lesson progress persistence, previous/next/review, and completion navigation remain wired to the existing environment and store.

Course, search-result, and related-content card buttons expose localized composite accessibility labels plus stable identifiers (`learn.lesson.<key>`, `explore.result.<key>`, and `explore.related.<key>`) for VoiceOver and UI automation.

## Validation

- `xcrun swiftc -frontend -parse CoastWild/UI/ExploreController.swift CoastWild/UI/LearnController.swift`
- `git diff --check -- CoastWild/UI/ExploreController.swift CoastWild/UI/LearnController.swift`

## Remaining gaps

- Figma MCP quota was exhausted, so the checked-in same-version JSON is the geometry and typography source.
- No Xcode build was run while the root task integrates CocoaPods, as requested.
- UIKit system navigation and safe-area behavior remain on secondary screens; the imported status/navigation chrome is not duplicated.
