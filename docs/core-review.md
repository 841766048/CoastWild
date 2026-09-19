# Native core review

## Fix verification

Commit `42a2d93` resolves all three findings from the initial review.

- **Resolved — full Trip item validation.** `saveTrip` rejects every negative item day and duplicate `(activityID, day)` pair before persistence (`CoastWild/Core/CoastStore.swift:76-100`). The new tests cover both the previously bypassable mixed negative/valid-day payload and duplicate full-payload save (`Tests/CoastWildCoreTests.swift:150-171`).
- **Resolved — account/ledger destination divergence.** `accountID` is now `public private(set)` (`CoastWild/Core/CoastStore.swift:19-22`), so callers must use `activate(accountID:)`, which loads the target ledger before publishing the new account and state (`CoastWild/Core/CoastStore.swift:46-61`).
- **Resolved — stable storage failures.** Directory creation, encoding, reading, decoding, and atomic writing now map Foundation errors to stable `CoastStoreError` keys and retain the underlying error (`CoastWild/Core/CoastStore.swift:29-43, 211-238`). The write-failure and corrupt-ledger tests also verify the stable keys and unchanged published state (`Tests/CoastWildCoreTests.swift:90-118`).

## Remaining finding

None in the targeted implementation.

- `setProgress` now persists the submitted non-negative step and keeps only completion sticky (`CoastWild/Core/CoastStore.swift:170-179`). The regression test covers backward navigation, reload, sticky completion, and negative-step rejection (`Tests/CoastWildCoreTests.swift:229-242`).
- Optional `CoastTripItem.time` and `CoastEntry.activityID` fields are present, default to `nil`, and decode legacy JSON that omits them (`CoastWild/Core/Models.swift:56-115`; `Tests/CoastWildCoreTests.swift:24-42`). Supplied times receive strict 24-hour `HH:mm` validation (`CoastWild/Core/Models.swift:148-158`).

### Documentation correction

The implementation report still says both progress step and completion are monotonic (`docs/core-report.md:19`), contradicting the corrected behavior and its own follow-up at `docs/core-report.md:47`. Change that sentence so only completion is described as sticky and step is described as the latest viewed position.

## Verdicts

- **Spec compliance: pass.** The progress, optional-time, and optional-entry-activity contract points are implemented correctly; all earlier material findings remain resolved.
- **Code quality: pass.** The latest-step and sticky-completion semantics are separated clearly, optional additions preserve stored-data compatibility, and time validation is centralized with the Trip rules.
- **Documentation: minor correction required.** `docs/core-report.md:19` is stale and contradicts the final implementation.
- **Test evidence:** implementer reports 20 Swift tests passing with 0 failures. Per review instructions, the suite was not rerun during this targeted re-review.
