# Remove content-region configuration

**Approved scope:** Apply to main, codex/native-uikit and codex/native-coin-learning. Remove region controls and China/US branching, preserve stored trips, dates, notes, units and V2-only features.

**Architecture:** Remove CoastPreferences.region; Codable ignores the legacy key. New trips default to TimeZone.current.identifier. CoastEntry.init(now:timeZone:) defaults to the current device zone; persisted date strings remain unchanged. Date picker serialization remains Gregorian/POSIX and UTC; only its empty-value default uses the current zone. Units remain independently configurable with existing km/c defaults; no country-based initialization.

## Tasks

- [ ] Add regression tests for ignoring legacy region keys, encoding without region, preserving units/user data and default trip timezone. Run tests and observe failure before production edits.
- [ ] Remove region property/initializer argument from Models.swift. Replace entry region initializer with init(now: Date = Date(), timeZone: TimeZone = .current). Remove AppDelegate country-to-unit preference initialization. Delete region controls in AuthController, ExploreController, ProfileController and TripsController; remove trip region edit state and submit-time timezone reassignment. JournalController uses CoastEntry(); DatePicker uses TimeZone.current. Update old tests to the approved contract.
- [ ] Run core tests and simulator build on native-uikit. Inspect diff, then commit only scoped files.
- [ ] Cherry-pick the scoped commit to the existing native-coin-learning worktree; resolve only contextual differences, never copy V1 app files wholesale. Run V2 tests and simulator build.
- [ ] Push verified commits to all three requested branches without force. Confirm main/native-uikit match and V2 retains its features.

## Verification

New regression tests decode a legacy CN preferences fixture and assert saved JSON has no region key, decode preferences with the key absent, and round-trip an existing trip and journal. Date tests cover midnight and winter offsets using explicit time zones; production defaults use the device zone. Source audit excludes obsolete region selectors while retaining locale country sent to existing APIs, backend catalog metadata, Xcode localization metadata and Firebase deployment regions. Historical documents/test fixtures may retain legacy values as evidence.

Use the existing public-content manifest for V1 Swift tests (COAST_PUBLIC_MANIFEST), and existing dependencies for xcodebuild with CODE_SIGNING_ALLOWED=NO. No backend deployment, data deletion, signing changes or dependency regeneration.
