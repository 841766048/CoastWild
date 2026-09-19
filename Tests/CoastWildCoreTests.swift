import XCTest
@testable import CoastWildCore

final class CoastWildCoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testModelsExposeContractDefaults() {
        let preferences = CoastPreferences()
        XCTAssertEqual(preferences.language, "zh-Hans")
        XCTAssertEqual(preferences.region, "CN")
        XCTAssertEqual(preferences.distanceUnit, "km")
        XCTAssertEqual(preferences.temperatureUnit, "c")
        XCTAssertFalse(preferences.onboardingDone)

        let trip = CoastTrip(name: "Coast")
        XCTAssertFalse(trip.id.isEmpty)
        XCTAssertEqual(trip.timeZone, "Asia/Shanghai")
        XCTAssertEqual(trip.items, [])
        XCTAssertNotNil(CoastValidation.parseDate(CoastEntry().date))
    }

    func testValidationUsesExactFieldLimitsAndDateRules() {
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "   ")), "trip.name.required")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: String(repeating: "a", count: 61))), "trip.name.tooLong")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "A", start: "2026-01-01")), "trip.date.incomplete")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "A", start: "2026-02-01", end: "2026-01-01")), "trip.date.range")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "A", start: "2026-02-30", end: "2026-03-01")), "trip.date.invalid")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "A", notes: String(repeating: "n", count: 1001))), "trip.notes.tooLong")
        XCTAssertNil(CoastValidation.trip(CoastTrip(name: " A ", start: "2026-01-01", end: "2026-01-01", notes: String(repeating: "n", count: 1000))))

        XCTAssertEqual(CoastValidation.entry(CoastEntry(title: String(repeating: "t", count: 81), body: "x", date: "2026-01-01", isDraft: false)), "entry.title.tooLong")
        XCTAssertEqual(CoastValidation.entry(CoastEntry(body: String(repeating: "b", count: 10001), date: "2026-01-01", isDraft: false)), "entry.body.tooLong")
        XCTAssertEqual(CoastValidation.entry(CoastEntry(date: "2026-01-01", isDraft: false)), "entry.content.required")
        XCTAssertEqual(CoastValidation.entry(CoastEntry(body: "x", date: "bad", isDraft: false)), "entry.date.invalid")
        XCTAssertEqual(CoastValidation.entry(CoastEntry(body: "x", date: "2026-01-01", photos: Array(repeating: "p", count: 13), isDraft: false)), "entry.photos.tooMany")
        XCTAssertNil(CoastValidation.entry(CoastEntry(title: String(repeating: "t", count: 80), body: String(repeating: "b", count: 10000), date: "2026-01-01", photos: Array(repeating: "p", count: 12), isDraft: false)))
    }

    func testEmailAndPasswordContract() {
        XCTAssertTrue(CoastValidation.email("person@example.com"))
        XCTAssertFalse(CoastValidation.email("person@example"))
        XCTAssertTrue(CoastValidation.email(String(repeating: "a", count: 242) + "@example.com"))
        XCTAssertFalse(CoastValidation.email(String(repeating: "a", count: 243) + "@example.com"))
        XCTAssertTrue(CoastValidation.password("1234567890"))
        XCTAssertTrue(CoastValidation.password(String(repeating: "x", count: 128)))
        XCTAssertFalse(CoastValidation.password("123456789"))
        XCTAssertFalse(CoastValidation.password(String(repeating: "x", count: 129)))
    }

    func testNoAccountDeniesBusinessMutationsAndActivationIsolatesReloads() throws {
        let store = try CoastStore(directory: directory)
        XCTAssertThrowsError(try store.saveTrip(CoastTrip(name: "Denied"))) { XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "account.required") }

        try store.activate(accountID: "first@example.com")
        let first = CoastTrip(name: "First")
        try store.saveTrip(first)
        try store.activate(accountID: "second@example.com")
        XCTAssertTrue(store.ledger.trips.isEmpty)
        try store.saveTrip(CoastTrip(name: "Second"))
        try store.activate(accountID: nil)
        XCTAssertTrue(store.ledger.trips.isEmpty)
        try store.activate(accountID: "first@example.com")
        XCTAssertEqual(store.ledger.trips.map(\.name), ["First"])

        let reloaded = try CoastStore(directory: directory)
        try reloaded.activate(accountID: "second@example.com")
        XCTAssertEqual(reloaded.ledger.trips.map(\.name), ["Second"])
    }

    func testInvalidAccountIdentifiersCannotTraverse() throws {
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "../../outside/😈")
        try store.saveTrip(CoastTrip(name: "Safe"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.deletingLastPathComponent().appendingPathComponent("outside").path))
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(names.count, 1)
        XCTAssertTrue(names[0].hasPrefix("ledger-"))
        XCTAssertTrue(names[0].hasSuffix(".json"))
    }

    func testCommitFailureDoesNotPublishLedger() throws {
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "a")
        let before = store.ledger
        try FileManager.default.removeItem(at: directory)
        var next = before
        next.trips.append(CoastTrip(name: "Never published"))
        XCTAssertThrowsError(try store.commit(next))
        XCTAssertEqual(store.ledger, before)
    }

    func testDuplicateActivitySameDayRejectedButOtherDayAllowed() throws {
        let store = try activeStore()
        let trip = CoastTrip(name: "Trip", start: "2026-01-01", end: "2026-01-03")
        try store.saveTrip(trip)
        try store.addActivity(tripID: trip.id, activityID: "hike", title: "Hike", day: 1)
        XCTAssertThrowsError(try store.addActivity(tripID: trip.id, activityID: "hike", title: "Again", day: 1)) { XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "trip.activity.duplicate") }
        try store.addActivity(tripID: trip.id, activityID: "hike", title: "Day two", day: 2)
        XCTAssertEqual(store.ledger.trips[0].items.count, 2)
    }

    func testActivityDayAndDateRangeCannotExcludeExistingItems() throws {
        let store = try activeStore()
        var trip = CoastTrip(name: "Trip", start: "2026-01-01", end: "2026-01-03")
        try store.saveTrip(trip)
        XCTAssertThrowsError(try store.addActivity(tripID: trip.id, activityID: "x", title: "X", day: 3)) { XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "trip.activity.dayOutOfRange") }
        try store.addActivity(tripID: trip.id, activityID: "x", title: "X", day: 2)
        trip = store.ledger.trips[0]
        trip.end = "2026-01-02"
        XCTAssertThrowsError(try store.saveTrip(trip)) { XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "trip.date.excludesItems") }
    }

    func testSaveTripRejectsOutOfRangeItemsInPayload() throws {
        let store = try activeStore()
        let item = CoastTripItem(activityID: "x", day: 2, titleSnapshot: "X")
        let trip = CoastTrip(name: "Trip", start: "2026-01-01", end: "2026-01-02", items: [item])
        XCTAssertThrowsError(try store.saveTrip(trip)) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "trip.date.excludesItems")
        }
    }

    func testDraftMayBeIncompleteButFinalEntryMustValidate() throws {
        let store = try activeStore()
        try store.saveEntry(CoastEntry(date: "", isDraft: true))
        XCTAssertEqual(store.ledger.entries.count, 1)
        XCTAssertThrowsError(try store.saveEntry(CoastEntry(body: String(repeating: "b", count: 10_001), date: "", isDraft: true))) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "entry.body.tooLong")
        }
        XCTAssertThrowsError(try store.saveEntry(CoastEntry(date: "2026-01-01", isDraft: false))) { XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "entry.content.required") }
    }

    func testFinalEntryGetsLocalizedUntitledName() throws {
        let store = try activeStore()
        let entry = CoastEntry(title: "  ", body: "Memory", date: "2026-01-01", isDraft: false)
        try store.saveEntry(entry)
        XCTAssertEqual(store.ledger.entries[0].title, "未命名手记")
    }

    func testEntryCannotReferenceMissingTrip() throws {
        let store = try activeStore()
        let entry = CoastEntry(body: "Memory", date: "2026-01-01", tripID: "missing", isDraft: false)
        XCTAssertThrowsError(try store.saveEntry(entry)) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "entry.trip.notFound")
        }
    }

    func testDeletingTripKeepsEntriesAndClearsReferences() throws {
        let store = try activeStore()
        let trip = CoastTrip(name: "Trip")
        try store.saveTrip(trip)
        let entry = CoastEntry(body: "Memory", date: "2026-01-01", tripID: trip.id, isDraft: false)
        try store.saveEntry(entry)
        try store.deleteTrip(id: trip.id)
        XCTAssertTrue(store.ledger.trips.isEmpty)
        XCTAssertEqual(store.ledger.entries.count, 1)
        XCTAssertNil(store.ledger.entries[0].tripID)
    }

    func testProgressAndBookmarksAreIdempotentAndExportIsDecodable() throws {
        let store = try activeStore()
        try store.setProgress(lessonID: "lesson", step: 3, completed: true)
        try store.setProgress(lessonID: "lesson", step: 2, completed: false)
        XCTAssertEqual(store.ledger.progress["lesson"], CoastProgress(step: 3, completed: true))
        try store.toggleBookmark("item")
        try store.toggleBookmark("item")
        XCTAssertFalse(store.ledger.bookmarks.contains("item"))
        XCTAssertNoThrow(try JSONDecoder().decode(CoastLedger.self, from: store.exportData()))
    }

    func testPreferencesPersistWithoutAccountAndClearOnlyCurrentLedger() throws {
        let store = try CoastStore(directory: directory)
        try store.updatePreferences(CoastPreferences(language: "en", region: "US", distanceUnit: "mi", temperatureUnit: "f", onboardingDone: true))
        try store.activate(accountID: "one")
        try store.saveTrip(CoastTrip(name: "One"))
        try store.activate(accountID: "two")
        try store.saveTrip(CoastTrip(name: "Two"))
        try store.clearCurrentLedger()
        let reloaded = try CoastStore(directory: directory)
        XCTAssertEqual(reloaded.preferences.language, "en")
        try reloaded.activate(accountID: "one")
        XCTAssertEqual(reloaded.ledger.trips.map(\.name), ["One"])
        try reloaded.activate(accountID: "two")
        XCTAssertTrue(reloaded.ledger.trips.isEmpty)
    }

    private func activeStore() throws -> CoastStore {
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "account")
        return store
    }
}
