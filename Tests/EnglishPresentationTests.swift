import XCTest
@testable import CoastWildCore

final class EnglishPresentationTests: XCTestCase {
    func testLegacyLanguageMigrationPreservesPreferencesAndUserContent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try CoastStore(directory: directory)
        try original.activate(accountID: "english-migration")
        let entry = CoastEntry(title: "我的海岸", body: "保留用户原文", date: "2026-09-29", photos: ["memory.jpg"], isDraft: false)
        try original.saveEntry(entry)
        var legacy = original.preferences
        legacy.language = "zh-Hans"
        legacy.region = "CN"
        legacy.distanceUnit = "km"
        legacy.temperatureUnit = "c"
        legacy.interests = ["surf"]
        legacy.onboardingDone = true
        let url = directory.appendingPathComponent("preferences.json")
        try JSONEncoder().encode(legacy).write(to: url)

        let migrated = try CoastStore(directory: directory)
        try migrated.activate(accountID: "english-migration")
        var expected = legacy
        expected.language = "en"
        XCTAssertEqual(migrated.preferences, expected)
        XCTAssertEqual(migrated.ledger.entries, original.ledger.entries)
        XCTAssertEqual(try JSONDecoder().decode(CoastPreferences.self, from: Data(contentsOf: url)), expected)
    }

    func testPreferenceUpdatesCannotEnableChinese() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CoastStore(directory: directory)
        var requested = store.preferences
        requested.language = "zh-Hans"
        requested.region = "CN"
        requested.distanceUnit = "km"
        try store.updatePreferences(requested)
        requested.language = "en"
        XCTAssertEqual(store.preferences, requested)
        XCTAssertEqual(try CoastStore(directory: directory).preferences, requested)
    }

    func testLegacyLegalLanguageResolvesEnglishPresentation() {
        for document in LegalDocument.allCases {
            XCTAssertEqual(document.title(language: "zh-Hans"), document.title(language: "en"))
            XCTAssertEqual(document.localResource(language: "zh-Hans"), "Legal/\(document.rawValue)-en")
            let key = "LEGAL_\(document.rawValue.uppercased())_URL_"
            let configuration = [key + "EN": "https://example.com/en", key + "ZH_HANS": "https://example.com/zh"]
            XCTAssertEqual(document.remoteURL(language: "zh-Hans", configuration: configuration)?.absoluteString, "https://example.com/en")
        }
    }
}
