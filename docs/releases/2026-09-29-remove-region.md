# Content-region settings removed

- Removed region selectors from onboarding, Explore, Preferences and the trip editor.
- Removed the stored preferences region property. Legacy JSON containing region is still readable; newly saved preferences omit it. Existing units and user content are preserved.
- New trips and journal dates use the device time zone. Existing trips keep their saved time zone; stored journal dates are not rewritten. Date-picker date-only serialization stays Gregorian/POSIX/UTC.
- Units remain configurable independently, with existing model defaults km/c for new installations. Country-based initial selection is removed.
- API device country, backend catalog metadata, Firebase deployment locations and Xcode localization metadata are not content-region preferences and remain unchanged.
- V2 retains its IAP, Web/Bridge and Adjust implementation and configuration.

## Verified locally

- V1: 190 Swift core tests; V2: 293 Swift core tests, all passing.
- Both branches: simulator Debug build and the new targeted UI regression test passed.
- UI test checks absence of region controls on Explore, Preferences and trip editor, and presence of units/date controls. Onboarding removal was source-reviewed; unit switching was not exercised by this new UI test.
- V1 Codemagic check script passed, including 12 CI tests, release-config checks and 15 content-tool tests.
- Independent review found no blocking issues. Git diff whitespace checks passed.

The first UI attempt used an unsigned app, which failed Keychain access at startup. Rerunning with simulator ad-hoc signing resolved it. A stale button label in the new test was corrected from “Create a trip” to the actual “Create trip”; final runs passed. No production signing settings were changed.
