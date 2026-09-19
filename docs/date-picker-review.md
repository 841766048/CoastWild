# Re-review outcome — regional default fix

**Clean for the bounded date-picker review.** The original P2 is closed.

`JournalEditorController` now uses `CoastEntry(region:)` only when no entry is supplied. Existing published entries, supplied drafts, and recovered edit drafts preserve their dates. The new initializer uses Gregorian/POSIX formatting with Asia/Shanghai or America/Los_Angeles; the date picker's empty default reuses that same initializer. Its UTC serialization and min/max clamping are preserved.

Inspected `/tmp/coast-date-timezone-fix.diff` and the root test log. `/tmp/coast-date-core-final.log` reports 24 tests with zero failures, including summer cross-midnight and winter PST boundary assertions. The explicit-date initializer preserves the tested leap-day value. No additional actionable findings in this fix. Root owns final build/UI verification; this reviewer ran neither.

---

# Original review (historical; P2 closed above)

# Date-picker bounded review

## [P2] New journal date bypasses the promised content-region default

`CoastWild/UI/JournalController.swift:106` supplies the already populated `entry.date` to the new date field. The new-entry path at `:79` still calls `CoastEntry()`, whose formatter uses the device timezone (`CoastWild/Core/Models.swift:92-98`). Therefore the region-based default in `CoastWild/UI/DatePicker.swift:21-24` never applies to new journal entries: it is only used for an empty/unparseable value.

Concrete case: Taipei device at 2026-09-20 00:30 with US content region creates a journal dated September 20, whereas the planned America/Los_Angeles default is September 19. The trip date picker and journal picker consequently disagree about “today.” Initialize only genuinely new journal entries with a shared region-aware today helper before creating the date field. Keep supplied entries and resumed drafts unchanged.

## Reviewed boundary

Reviewed `/tmp/coast-date-review.diff`, current date wrapper/call sites, plan, and installed BRPickerView 3.0.0 date/callback implementation. No additional actionable runtime, cancellation, date-range, serialization, or draft-event findings identified. BR custom wheel mode uses the configured UTC timezone; dates and day offsets remain UTC-based, confirmation emits valueChanged for journal autosave, cancellation does not invoke the result block, and required journal dates omit Clear. Pods dependency and source registration are present.

Observed existing root logs: workspace build succeeded (`/tmp/coast-date-build.log`), 23 core tests passed (`/tmp/coast-date-core.log`). Root's UI run is pending; no tests/builds were run by this reviewer. Only this report was written.
