# Native UI review fixes

## Scope

- Search clear now resets the query model, visible search text, category model, visible category segment, and duration filter together.
- Existing trip edits preserve the stored destination timezone; only new trips initialize a timezone from the current content region.
- Trip activity menus can move an existing item to another day without changing its identity, title snapshot, or optional time. Short trips use a day menu; trips longer than 14 days use bounded numeric input so the UI does not construct an unbounded action list. `saveTrip` remains the duplicate/range validation boundary.
- Failed exports remove the temporary export folder as well as successful or cancelled shares.
- Clearing local content clears only the active account ledger and photo folder, resets onboarding, logs out, and presents the first-use root. Other account ledgers remain stored.
- EX01 and the root Trips screen no longer duplicate their visible page heading in the navigation bar. EX01 uses pale icon-led region/search fields, a tappable 248-point hero, and two 160-point image tiles for the first recommendations.

## Verification

- `xcrun swiftc -parse CoastWild/UI/ExploreController.swift CoastWild/UI/TripsController.swift CoastWild/UI/ProfileController.swift` passed.
- `git diff --check` passed for the three owned controllers.
- `xcodebuild -project CoastWild.xcodeproj -scheme CoastWild -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build` passed with `** BUILD SUCCEEDED **`.
- UI tests were intentionally left to the root task after this commit to avoid simulator concurrency.
