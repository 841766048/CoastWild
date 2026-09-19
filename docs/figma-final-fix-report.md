# Figma final fix report

## Changes

- Added explicit accessibility labels and stable identifiers to custom trip hero cards, activity picker cards, timeline option buttons, linked trip journal cards, and journal list cards. Picker cards expose the selected accessibility trait.
- Restored visible linked-experience state in the journal editor. The summary appears when an experience is linked, opens the experience menu, updates after selection, and hides after clearing.
- Grouped TR03 timeline rows in a zero-spacing stack for a 64-point pitch. Category badges now use the source colors (`#F9EDD5` for hike/camp, `#DFF0F4` for surf) and the original 24-point category icons.
- Carried the normalized recovery email from recovery into reset mode and displayed it below the reset hierarchy with `auth.recovery.email`.
- Preserved the composite Units summary while determining the checked distance action from `distanceUnit`. Preference selects now keep their chevron pinned 12 points from the trailing edge.
- Matched private trip and journal placeholder colors to `#757575`, retaining each field's font size and weight.
- Updated the onboarding explore-region row to use the map/trips icon and restored the trailing down chevron.
- Restored the TR04 picker’s visible selected state: the selected card uses the reference brand border while retaining the `.selected` accessibility trait.

## Accessibility identifiers

- `trip.card.<trip-id>`
- `trip.activity.<catalog-key>`
- `trip.timeline.options.<item-id>`
- `trip.journal.<entry-id>`
- `journal.card.<entry-id>`
- `journal.link.trip`
- `journal.link.activity`
- `auth.recovery.email`

## Validation

- Passed: `xcrun swiftc -parse CoastWild/UI/TripsController.swift CoastWild/UI/JournalController.swift CoastWild/UI/AuthController.swift CoastWild/UI/ProfileController.swift`
- Passed: `git diff --check -- CoastWild/UI/TripsController.swift CoastWild/UI/JournalController.swift CoastWild/UI/AuthController.swift CoastWild/UI/ProfileController.swift`
- Per coordination instructions, `xcodebuild` was not run during this wave.

### Picker selected-state follow-up

- Passed: `xcrun swiftc -parse CoastWild/UI/TripsController.swift`
- Passed: `git diff --check -- CoastWild/UI/TripsController.swift docs/figma-final-fix-report.md`
- `xcodebuild` was not run.
