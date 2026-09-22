import XCTest
@testable import CoastWildCore

private enum TestStorageError: Error { case failed }

private final class MemoryAccountDataStore: AccountDataStore {
    var data: Data?
    var saveError: Error?

    init(data: Data? = nil, saveError: Error? = nil) {
        self.data = data
        self.saveError = saveError
    }

    func load() throws -> Data? { data }
    func save(_ data: Data) throws {
        if let saveError { throw saveError }
        self.data = data
    }
    func remove() throws { data = nil }
}

final class CoastWildCoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testUserDefaultsAccountDataStorePersistsAndRemovesData() throws {
        let suite = "CoastWildCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsAccountDataStore(defaults: defaults, key: "accounts")
        let payload = Data("account-data".utf8)

        XCTAssertNil(try store.load())
        try store.save(payload)
        XCTAssertEqual(try UserDefaultsAccountDataStore(defaults: defaults, key: "accounts").load(), payload)
        try store.remove()
        XCTAssertNil(try store.load())
    }

    func testUserDefaultsAccountDataStoreKeepsKeysIsolated() throws {
        let suite = "CoastWildCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let production = UserDefaultsAccountDataStore(defaults: defaults, key: "accounts.production")
        let testing = UserDefaultsAccountDataStore(defaults: defaults, key: "accounts.testing")

        try production.save(Data("production".utf8))
        try testing.save(Data("testing".utf8))

        XCTAssertEqual(try production.load(), Data("production".utf8))
        XCTAssertEqual(try testing.load(), Data("testing".utf8))
    }

    func testPrivacyConsentRequiresCurrentVersionAndPersistsAcceptance() throws {
        let suite = "CoastWildCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let consent = PrivacyConsentStore(defaults: defaults, key: "privacy", currentVersion: 2)

        XCTAssertFalse(consent.isAccepted)
        consent.accept()
        XCTAssertTrue(consent.isAccepted)
        XCTAssertTrue(PrivacyConsentStore(defaults: defaults, key: "privacy", currentVersion: 2).isAccepted)
        XCTAssertFalse(PrivacyConsentStore(defaults: defaults, key: "privacy", currentVersion: 3).isAccepted)
    }

    func testPrivacyConsentResetOnlyRemovesItsOwnValue() throws {
        let suite = "CoastWildCoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("account", forKey: "account-data")
        let consent = PrivacyConsentStore(defaults: defaults, key: "privacy", currentVersion: 1)
        consent.accept()

        consent.reset()

        XCTAssertFalse(consent.isAccepted)
        XCTAssertEqual(defaults.string(forKey: "account-data"), "account")
    }

    func testLegalDocumentsResolveLocalizedBundleResources() {
        XCTAssertEqual(LegalDocument.privacy.localResource(language: "en"), "Legal/privacy-en")
        XCTAssertEqual(LegalDocument.privacy.localResource(language: "zh-Hans"), "Legal/privacy-zh-Hans")
        XCTAssertEqual(LegalDocument.terms.localResource(language: "zh-CN"), "Legal/terms-zh-Hans")
        XCTAssertEqual(LegalDocument.terms.title(language: "en"), "Terms of Use")
        XCTAssertEqual(LegalDocument.privacy.title(language: "zh-Hans"), "隐私政策")
    }

    func testLegalDocumentsAcceptOnlyConfiguredHTTPSRemoteURLs() {
        let values = [
            "LEGAL_PRIVACY_URL_EN": "https://legal.coastwild.app/en/privacy",
            "LEGAL_TERMS_URL_EN": "http://legal.coastwild.app/en/terms",
        ]

        XCTAssertEqual(
            LegalDocument.privacy.remoteURL(language: "en", configuration: values)?.absoluteString,
            "https://legal.coastwild.app/en/privacy")
        XCTAssertNil(LegalDocument.terms.remoteURL(language: "en", configuration: values))
        XCTAssertNil(LegalDocument.privacy.remoteURL(language: "zh-Hans", configuration: values))
    }

    func testMigratingAccountDataStoreCopiesLegacyDataThenRemovesIt() throws {
        let destination = MemoryAccountDataStore()
        let legacy = MemoryAccountDataStore(data: Data("legacy".utf8))
        let store = MigratingAccountDataStore(destination: destination, legacy: legacy)

        XCTAssertEqual(try store.load(), Data("legacy".utf8))
        XCTAssertEqual(destination.data, Data("legacy".utf8))
        XCTAssertNil(legacy.data)
    }

    func testMigratingAccountDataStoreLeavesLegacyDataWhenDestinationWriteFails() throws {
        let destination = MemoryAccountDataStore(saveError: TestStorageError.failed)
        let legacy = MemoryAccountDataStore(data: Data("legacy".utf8))
        let store = MigratingAccountDataStore(destination: destination, legacy: legacy)

        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(legacy.data, Data("legacy".utf8))
    }

    func testNewJournalDateUsesContentRegionAcrossMidnight() {
        let now = ISO8601DateFormatter().date(from: "2026-09-19T16:30:00Z")!
        XCTAssertEqual(CoastEntry(region: "CN", now: now).date, "2026-09-20")
        XCTAssertEqual(CoastEntry(region: "US", now: now).date, "2026-09-19")
        let winter = ISO8601DateFormatter().date(from: "2026-01-01T07:30:00Z")!
        XCTAssertEqual(CoastEntry(region: "US", now: winter).date, "2025-12-31")
        XCTAssertEqual(CoastEntry(date: "2024-02-29").date, "2024-02-29")
    }

    func testMotionContractMatchesApprovedTiming() {
        XCTAssertEqual(CoastMotion.pushDuration, 0.28)
        XCTAssertEqual(CoastMotion.popDuration, 0.24)
        XCTAssertEqual(CoastMotion.tabDuration, 0.18)
        XCTAssertEqual(CoastMotion.tabOffset, 6)
        XCTAssertEqual(CoastMotion.dialogOpenDuration, 0.22)
        XCTAssertEqual(CoastMotion.dialogCloseDuration, 0.16)
        XCTAssertEqual(CoastMotion.dialogOpenScale, 0.96)
        XCTAssertEqual(CoastMotion.dialogCloseScale, 0.98)
        XCTAssertLessThanOrEqual(CoastMotion.reducedDuration, 0.12)
    }

    func testLearningArticleSeparatesWebAndNativePayloads() throws {
        let webJSON = #"{"key":"surf-guide","category":"surf","detailType":"web","title":{"en":"Guide","zh-Hans":"指南"},"summary":{"en":"Summary","zh-Hans":"摘要"},"group":{"en":"Start","zh-Hans":"入门"},"heroImage":"surf-coast","icon":"water.waves","readingMinutes":8,"level":"beginner","tags":[],"sourceLinks":[{"title":{"en":"NOAA","zh-Hans":"NOAA"},"organization":"NOAA","url":"https://www.noaa.gov"}],"webDetail":{"author":{"en":"Editorial","zh-Hans":"编辑部"},"updatedAt":"2026-09","highlights":[],"blocks":[{"type":"paragraph","title":{"en":"Conditions","zh-Hans":"海况"},"body":{"en":"Look first.","zh-Hans":"先观察。"}}]},"nativeDetail":null}"#
        let nativeJSON = #"{"key":"surf-step","category":"surf","detailType":"native","title":{"en":"Board","zh-Hans":"冲浪板"},"summary":{"en":"Learn parts","zh-Hans":"认识结构"},"group":{"en":"Start","zh-Hans":"入门"},"heroImage":"board-diagram","icon":"figure.surfing","readingMinutes":5,"level":"beginner","tags":[],"sourceLinks":[],"webDetail":null,"nativeDetail":{"steps":[{"title":{"en":"Nose","zh-Hans":"板头"},"body":{"en":"Find it.","zh-Hans":"找到它。"},"image":"board-diagram","icon":"arrow.up"}]}}"#
        let decoder = JSONDecoder()
        let web = try decoder.decode(CoastLesson.self, from: Data(webJSON.utf8))
        let native = try decoder.decode(CoastLesson.self, from: Data(nativeJSON.utf8))
        XCTAssertTrue(web.isValid())
        XCTAssertEqual(web.detailType, .web)
        XCTAssertTrue(native.isValid())
        XCTAssertEqual(native.steps.first?.assetName, "board-diagram")
    }

    func testCatalogContainsCompleteLearningLibrary() throws {
        struct Fixture: Decodable { let lessons: [CoastLesson] }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("CoastWild/Resources/catalog.json"))
        let lessons = try JSONDecoder().decode(Fixture.self, from: data).lessons
        XCTAssertEqual(lessons.count, 45)
        XCTAssertEqual(Set(lessons.map(\.key)).count, 45)
        for category in ["surf", "hike", "camp"] {
            let categoryLessons = lessons.filter { $0.category == category }
            XCTAssertEqual(categoryLessons.count, 15)
            XCTAssertEqual(categoryLessons.filter { $0.detailType == .web }.count, 8)
            XCTAssertEqual(categoryLessons.filter { $0.detailType == .native }.count, 7)
        }
        XCTAssertTrue(lessons.allSatisfy { $0.isValid() })
        let ids = Set(lessons.map(\.key))
        XCTAssertTrue(lessons.compactMap { $0.webDetail?.nextLessonID }.allSatisfy(ids.contains))
        XCTAssertTrue(lessons.allSatisfy { $0.image == "learn-\($0.key)-photo" })
        XCTAssertTrue(lessons.flatMap(\.steps).allSatisfy { $0.assetName.hasPrefix("learn-") && $0.assetName.hasSuffix("-illustration") })
    }

    func testEveryLearningLessonUsesItsOwnPhotoAndIllustration() throws {
        struct Fixture: Decodable { let lessons: [CoastLesson] }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("CoastWild/Resources/catalog.json"))
        let lessons = try JSONDecoder().decode(Fixture.self, from: data).lessons

        XCTAssertEqual(Set(lessons.map(\.image)).count, 45)
        for lesson in lessons {
            let photo = "learn-\(lesson.key)-photo"
            let illustration = "learn-\(lesson.key)-illustration"
            XCTAssertEqual(lesson.image, photo)
            if lesson.detailType == .web {
                let images = lesson.webDetail?.blocks.compactMap(\.image) ?? []
                XCTAssertTrue(images.contains(illustration), "Missing illustration for \(lesson.key)")
            } else {
                XCTAssertFalse(lesson.steps.isEmpty)
                XCTAssertTrue(lesson.steps.allSatisfy { $0.assetName == illustration })
            }
        }
    }

    func testModelsExposeContractDefaults() {
        let preferences = CoastPreferences()
        XCTAssertEqual(preferences.language, "en")
        XCTAssertEqual(preferences.region, "CN")
        XCTAssertEqual(preferences.distanceUnit, "km")
        XCTAssertEqual(preferences.temperatureUnit, "c")
        XCTAssertFalse(preferences.onboardingDone)
        XCTAssertNil(preferences.interests)

        let trip = CoastTrip(name: "Coast")
        XCTAssertFalse(trip.id.isEmpty)
        XCTAssertEqual(trip.timeZone, "Asia/Shanghai")
        XCTAssertEqual(trip.items, [])
        XCTAssertNil(trip.coverPhoto)
        let entry = CoastEntry()
        XCTAssertNotNil(CoastValidation.parseDate(entry.date))
        XCTAssertNil(entry.activityID)
        XCTAssertNil(entry.sourceEntryID)
        XCTAssertNil(CoastTripItem(activityID: "walk", titleSnapshot: "Walk").time)
        XCTAssertNil(CoastProgress().completedAt)
    }

    func testOptionalContractFieldsDecodeFromLegacyJSONWhenAbsent() throws {
        let preferencesData = Data(#"{"language":"zh-Hans","region":"CN","distanceUnit":"km","temperatureUnit":"c","onboardingDone":false}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(CoastPreferences.self, from: preferencesData).interests)

        let itemData = Data(#"{"id":"item","activityID":"walk","day":0,"titleSnapshot":"Walk"}"#.utf8)
        let item = try JSONDecoder().decode(CoastTripItem.self, from: itemData)
        XCTAssertNil(item.time)

        let entryData = Data(#"{"id":"entry","title":"Title","body":"Body","date":"2026-01-01","photos":[],"isDraft":false}"#.utf8)
        let entry = try JSONDecoder().decode(CoastEntry.self, from: entryData)
        XCTAssertNil(entry.activityID)
        XCTAssertNil(entry.sourceEntryID)

        let progressData = Data(#"{"step":2,"completed":true}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(CoastProgress.self, from: progressData).completedAt)

        let tripData = Data(#"{"id":"trip","name":"Legacy","start":"","end":"","notes":"","timeZone":"Asia/Shanghai","completed":false,"items":[]}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(CoastTrip.self, from: tripData).coverPhoto)
    }

    func testTripCoverFilenameRoundTripsThroughStore() throws {
        let store = try activeStore()
        let trip = CoastTrip(name: "Mountain weekend", coverPhoto: "cover-123.jpg")
        try store.saveTrip(trip)

        let reloaded = try CoastStore(directory: directory)
        try reloaded.activate(accountID: "account")
        XCTAssertEqual(reloaded.ledger.trips.first?.coverPhoto, "cover-123.jpg")
    }

    func testReferencedPhotosIncludeJournalImagesAndTripCovers() {
        let ledger = CoastLedger(
            trips: [CoastTrip(name: "Covered", coverPhoto: "trip-cover.jpg"), CoastTrip(name: "Default")],
            entries: [CoastEntry(body: "Entry", date: "2026-09-20", photos: ["journal-1.jpg", "journal-2.jpg"])])

        XCTAssertEqual(ledger.referencedPhotoFilenames, ["trip-cover.jpg", "journal-1.jpg", "journal-2.jpg"])
    }

    func testValidationUsesExactFieldLimitsAndDateRules() {
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "   ")), "trip.name.required")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: String(repeating: "a", count: 61))), "trip.name.tooLong")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "A", start: "2026-01-01")), "trip.date.incomplete")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "A", start: "2026-02-01", end: "2026-01-01")), "trip.date.range")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "A", start: "2026-02-30", end: "2026-03-01")), "trip.date.invalid")
        XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "A", notes: String(repeating: "n", count: 1001))), "trip.notes.tooLong")
        XCTAssertNil(CoastValidation.trip(CoastTrip(name: " A ", start: "2026-01-01", end: "2026-01-01", notes: String(repeating: "n", count: 1000))))

        let validTimeItem = CoastTripItem(activityID: "x", titleSnapshot: "X", time: "23:59")
        XCTAssertNil(CoastValidation.trip(CoastTrip(name: "A", items: [validTimeItem])))
        for invalidTime in ["24:00", "12:60", "9:30", "09:3", ""] {
            let item = CoastTripItem(activityID: "x", titleSnapshot: "X", time: invalidTime)
            XCTAssertEqual(CoastValidation.trip(CoastTrip(name: "A", items: [item])), "trip.activity.time.invalid")
        }

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
        XCTAssertThrowsError(try store.commit(next)) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "storage.write")
            XCTAssertNotNil(($0 as? CoastStoreError)?.underlyingError)
        }
        XCTAssertEqual(store.ledger, before)
    }

    func testCorruptAccountFileExposesStableDecodeErrorAndDoesNotActivate() throws {
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "good")
        try store.saveTrip(CoastTrip(name: "Good"))

        let corruptURL = directory.appendingPathComponent("ledger-\(stableHash("corrupt")).json")
        try Data("not-json".utf8).write(to: corruptURL)

        XCTAssertThrowsError(try store.activate(accountID: "corrupt")) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "storage.decode")
            XCTAssertNotNil(($0 as? CoastStoreError)?.underlyingError)
        }
        XCTAssertEqual(store.accountID, "good")
        XCTAssertEqual(store.ledger.trips.map(\.name), ["Good"])
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

    func testSaveTripRejectsNegativeItemHiddenByValidItem() throws {
        let store = try activeStore()
        let items = [
            CoastTripItem(activityID: "bad", day: -1, titleSnapshot: "Bad"),
            CoastTripItem(activityID: "good", day: 0, titleSnapshot: "Good")
        ]
        let trip = CoastTrip(name: "Trip", items: items)
        XCTAssertThrowsError(try store.saveTrip(trip)) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "trip.activity.dayOutOfRange")
        }
    }

    func testSaveTripRejectsDuplicateActivityAndDayPairs() throws {
        let store = try activeStore()
        let items = [
            CoastTripItem(activityID: "same", day: 0, titleSnapshot: "First"),
            CoastTripItem(activityID: "same", day: 0, titleSnapshot: "Second")
        ]
        XCTAssertThrowsError(try store.saveTrip(CoastTrip(name: "Trip", items: items))) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "trip.activity.duplicate")
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
        XCTAssertEqual(store.ledger.entries[0].title, "Untitled entry")
    }

    func testEntryCannotReferenceMissingTrip() throws {
        let store = try activeStore()
        let entry = CoastEntry(body: "Memory", date: "2026-01-01", tripID: "missing", isDraft: false)
        XCTAssertThrowsError(try store.saveEntry(entry)) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "entry.trip.notFound")
        }
    }

    func testLinkedDraftPreservesPublishedEntryUntilFinalAtomicallyReplacesIt() throws {
        let store = try activeStore()
        let published = CoastEntry(id: "published", body: "Original", date: "2026-01-01", isDraft: false)
        try store.saveEntry(published)
        var draft = CoastEntry(id: "draft", body: "Edited", date: "2026-01-02", isDraft: true, sourceEntryID: published.id)
        try store.saveEntry(draft)

        XCTAssertEqual(store.ledger.entries.count, 2)
        XCTAssertEqual(store.ledger.entries.first(where: { $0.id == published.id })?.body, "Original")
        XCTAssertEqual(store.ledger.entries.first(where: { $0.id == draft.id })?.body, "Edited")

        draft.isDraft = false
        try store.saveEntry(draft)
        XCTAssertEqual(store.ledger.entries.count, 1)
        XCTAssertEqual(store.ledger.entries[0].id, published.id)
        XCTAssertEqual(store.ledger.entries[0].body, "Edited")
        XCTAssertNil(store.ledger.entries[0].sourceEntryID)
    }

    func testLinkedDraftResumesAfterReloadAndFinalRequiresPublishedSource() throws {
        let store = try activeStore()
        try store.saveEntry(CoastEntry(id: "published", body: "Original", date: "2026-01-01", isDraft: false))
        try store.saveEntry(CoastEntry(id: "draft", body: "Edited", date: "2026-01-02", isDraft: true, sourceEntryID: "published"))

        let reloaded = try CoastStore(directory: directory)
        try reloaded.activate(accountID: "account")
        var resumed = try XCTUnwrap(reloaded.ledger.entries.first(where: { $0.id == "draft" }))
        resumed.isDraft = false
        try reloaded.saveEntry(resumed)

        let verified = try CoastStore(directory: directory)
        try verified.activate(accountID: "account")
        XCTAssertEqual(verified.ledger.entries.map(\.id), ["published"])
        XCTAssertEqual(verified.ledger.entries[0].body, "Edited")

        let orphan = CoastEntry(id: "orphan-draft", body: "Lost", date: "2026-01-03", isDraft: false, sourceEntryID: "missing")
        XCTAssertThrowsError(try verified.saveEntry(orphan)) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "entry.source.notFound")
        }
    }

    func testDeletingPublishedEntryCascadesLinkedDraftsButKeepsPlainDrafts() throws {
        let store = try activeStore()
        try store.saveEntry(CoastEntry(id: "published", body: "Original", date: "2026-01-01", isDraft: false))
        try store.saveEntry(CoastEntry(id: "linked", body: "Edited", date: "2026-01-02", isDraft: true, sourceEntryID: "published"))
        try store.saveEntry(CoastEntry(id: "plain", date: "", isDraft: true))

        try store.deleteEntry(id: "published")
        XCTAssertEqual(store.ledger.entries.map(\.id), ["plain"])
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

    func testProgressPersistsBackwardNavigationAcrossReloadAndCompletionIsSticky() throws {
        let store = try activeStore()
        try store.setProgress(lessonID: "lesson", step: 3, completed: true)
        let firstCompletedAt = try XCTUnwrap(store.ledger.progress["lesson"]?.completedAt)
        try store.setProgress(lessonID: "lesson", step: 2, completed: false)
        XCTAssertEqual(store.ledger.progress["lesson"]?.step, 2)
        XCTAssertEqual(store.ledger.progress["lesson"]?.completed, true)
        XCTAssertEqual(store.ledger.progress["lesson"]?.completedAt, firstCompletedAt)

        try store.setProgress(lessonID: "lesson", step: 2, completed: true)
        XCTAssertEqual(store.ledger.progress["lesson"]?.completedAt, firstCompletedAt)

        let reloaded = try CoastStore(directory: directory)
        try reloaded.activate(accountID: "account")
        XCTAssertEqual(reloaded.ledger.progress["lesson"]?.step, 2)
        XCTAssertEqual(reloaded.ledger.progress["lesson"]?.completed, true)
        XCTAssertEqual(reloaded.ledger.progress["lesson"]?.completedAt, firstCompletedAt)
        XCTAssertThrowsError(try reloaded.setProgress(lessonID: "lesson", step: -1, completed: false)) {
            XCTAssertEqual(($0 as? LocalizedError)?.errorDescription, "progress.step.invalid")
        }
    }

    func testBookmarksAreIdempotentAndExportIsDecodable() throws {
        let store = try activeStore()
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

    private func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
