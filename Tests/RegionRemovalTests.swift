import XCTest
@testable import CoastWildCore

final class RegionRemovalTests: XCTestCase {
    func testLegacyRegionIsIgnoredWithoutLosingPreferences() throws {
        let data = Data(#"{"language":"en","region":"CN","distanceUnit":"mi","temperatureUnit":"f","onboardingDone":true,"interests":["surf"]}"#.utf8)
        let preferences = try JSONDecoder().decode(CoastPreferences.self, from: data)
        XCTAssertEqual(preferences.distanceUnit, "mi")
        XCTAssertEqual(preferences.temperatureUnit, "f")
        XCTAssertTrue(preferences.onboardingDone)
        XCTAssertEqual(preferences.interests, ["surf"])
        let encoded = try JSONEncoder().encode(preferences)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(object["region"])
        XCTAssertEqual(try JSONDecoder().decode(CoastPreferences.self, from: encoded), preferences)
    }

    func testPreferencesDecodeWithoutRegion() throws {
        let data = Data(#"{"language":"en","distanceUnit":"km","temperatureUnit":"c","onboardingDone":false}"#.utf8)
        let preferences = try JSONDecoder().decode(CoastPreferences.self, from: data)
        XCTAssertEqual(preferences.distanceUnit, "km")
        XCTAssertEqual(preferences.temperatureUnit, "c")
    }

    func testNewTripsUseDeviceTimeZone() {
        XCTAssertEqual(CoastTrip(name: "New trip").timeZone, TimeZone.current.identifier)
    }

    func testExistingTripAndEntrySurviveStoreReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try CoastStore(directory: directory)
        try store.activate(accountID: "region-migration")
        let trip = CoastTrip(name: "Saved trip", start: "2026-09-29", end: "2026-09-30", notes: "Keep notes", timeZone: "Asia/Shanghai")
        let entry = CoastEntry(title: "Saved entry", body: "Keep text", date: "2026-09-28", photos: ["photo.jpg"], isDraft: false)
        try store.saveTrip(trip)
        try store.saveEntry(entry)
        let reloaded = try CoastStore(directory: directory)
        try reloaded.activate(accountID: "region-migration")
        XCTAssertEqual(reloaded.ledger.trips, store.ledger.trips)
        XCTAssertEqual(reloaded.ledger.entries, store.ledger.entries)
    }
}
