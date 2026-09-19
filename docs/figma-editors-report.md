# Figma editors alignment report

## Scope

Updated `TripsController.swift` and `JournalController.swift` against the local HF-v1.2 JSON for TR01–TR04, JO01–JO03, and their referenced state screens. No WebView or static screenshot UI was introduced.

## Coverage

- TR01: 32-point root title with sand 44-point add action, planned/completed segment, 264-point bordered hero, secondary image rows, and shared ST05 empty state with embedded CTA.
- TR02: cancel/title/save navigation, `trip.save` identifier, grouped 34-point inset form panels, explicit region selection, paired dates, 105-point notes, and no duplicate bottom save button. Existing time zones are preserved unless the user changes region.
- TR03: 27-point heading, 163-point image, date, compact day segments with bounded picker fallback for longer trips, and time/image/title/category timeline rows. Change-day, reorder, remove, completion, deletion, journal, and edit actions remain connected.
- TR04: date and time selectors plus bordered catalog rows while retaining duplicate prevention and pending content behavior.
- JO01: 32-point title/add header, subtitle and draft count filter, bordered whole-card interaction, optional real photo only, and 13/22/14/13-point content hierarchy. Shared ST08 empty state includes its CTA.
- JO02: borderless 26-point title field, date field, 50-point photo action, borderless 220-point body with 26.4-point line height and placeholder, grouped trip/optional activity selectors, 12-point status, navbar save/cancel, and unchanged autosave/photo lifecycle.
- JO03: first real photo at 274 points before date/title/body, 32-point title, 16/26.4-point body, remaining photo gallery, linked trip, share, edit, and delete behavior.

## Validation

- `xcrun swiftc -parse CoastWild/UI/TripsController.swift CoastWild/UI/JournalController.swift`
- `git diff --check -- CoastWild/UI/TripsController.swift CoastWild/UI/JournalController.swift`
- Source audit confirmed persistence, validation, pending content, activity ordering/removal, draft debounce, photo import/removal/cleanup, share, and destructive confirmation paths remain present.
- Full standalone `swiftc -typecheck` could not resolve the root-owned CocoaPods modules (`IQKeyboardManagerSwift`, `IQKeyboardToolbarManager`, `IQKeyboardToolbar`) outside the workspace build. Per task instructions, no `xcodebuild`, pod install, or xcodegen command was run.

## Review corrections

- Added the linked, published journal section to TR03 with whole bordered journal cards and detail routing.
- Added the JO03 bottom edit/delete actions, reduced the header to one More action, and retained sharing inside that menu.
- Switched local inputs to the shared `inputFill` color and 9-point radius.
- Matched the borderless fixed-height TR02 cards, soft page background, vertical region field, and exact root spacing.
- Replaced private subview traversal with stored buttons and `UIButton.Configuration` title updates.
- Added the 64-point TR03 time/badge/copy/options rows and 91-point TR04 catalog cards.
- Tightened JO02 to the inspected date/photo/body/trip/status positions, hid the empty photo stack, and kept optional activity linking in the linked selector menu.

## Known gaps

- Visual alignment is based on the exact local JSON geometry and typography; no simulator screenshot comparison was available in this bounded task, so this report does not claim pixel-perfect parity.
- Secondary UIKit pages retain the navigation bar as specified.
