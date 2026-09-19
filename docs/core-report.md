# Native core implementation report

## Scope

- Added the Swift 5 package manifest for the Foundation-only core and macOS XCTest execution.
- Added Codable/Identifiable domain models for preferences, trips, trip items, journal entries, progress, and account ledgers.
- Added stable-key validation for trip fields, calendar dates, journal limits, email, and password.
- Added atomic JSON persistence with independent preferences, hashed per-account filenames, account activation/isolation, and a cleared in-memory ledger while signed out.
- Added trip, activity, journal, bookmark, progress, clear, and export operations.

## Persistence and mutation semantics

- All business writes require an active account and throw `account.required` otherwise.
- Ledger state is published in memory only after the atomic file write succeeds.
- Account activation loads its own ledger; activating `nil` hides all business data without deleting account files.
- Account identifiers are never used as path components. A stable hash produces `ledger-<hash>.json` filenames.
- Deleting a trip preserves journal entries and clears their trip references.
- Draft journal entries may be incomplete, while title/body/photo limits remain enforced. Final entries receive a localized untitled name when blank.
- Progress step and completion values are monotonic, making repeated completion calls idempotent.

## Verification

`swift test` passes 18 tests with 0 failures. Coverage includes model defaults, exact limits, strict dates, auth field validation, account denial/isolation/reload, path traversal resistance, failed-write rollback, corrupt-data rollback, duplicate activities through both write paths, activity date bounds, draft/final journal behavior, trip deletion references, preferences, bookmarks, progress, clearing, and export decoding.

## API notes

No required API was removed or renamed. The models additionally conform to `Equatable` for value assertions, and `CoastStoreError` is public so UI code may inspect its stable `LocalizedError.errorDescription` key. `saveEntry` also enforces the existing-trip relationship and localizes a blank final title, as required by the sibling field contract.

## Core review follow-up

- `saveTrip` now checks every submitted item's non-negative day and rejects duplicate `(activityID, day)` pairs before writing. This keeps direct full-payload saves consistent with `addActivity`.
- `accountID` is now `public private(set)`. Only `activate(accountID:)` can switch accounts, so the visible ledger and its persistence destination cannot diverge.
- Directory creation, reads, decoding, encoding, and atomic writes now map Foundation failures to `CoastStoreError` while retaining the original error in `underlyingError`. Failed reads and writes do not publish partial state.

Stable keys currently emitted by the core are:

- Account: `account.required`
- Storage: `storage.directory`, `storage.read`, `storage.decode`, `storage.encode`, `storage.write`
- Trip: `trip.name.required`, `trip.name.tooLong`, `trip.notes.tooLong`, `trip.date.incomplete`, `trip.date.invalid`, `trip.date.range`, `trip.date.excludesItems`, `trip.notFound`, `trip.activity.dayOutOfRange`, `trip.activity.duplicate`
- Entry: `entry.title.tooLong`, `entry.body.tooLong`, `entry.photos.tooMany`, `entry.content.required`, `entry.date.invalid`, `entry.trip.notFound`
