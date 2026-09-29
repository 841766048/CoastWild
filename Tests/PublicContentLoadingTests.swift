import XCTest
@testable import CoastWildCore

final class PublicContentLoadingTests: XCTestCase {
    func testEmptyPublishedCatalogIsValid() throws {
        let release = PublicContentRelease(schemaVersion: 1, version: String(repeating: "a", count: 64),
            catalogJSON: #"{"items":[],"lessons":[],"categories":[]}"#, images: [])
        XCTAssertNoThrow(try release.validate())
    }

    func testFirestoreEmptyArrayWithoutValuesDecodesAndCaches() throws {
        let json = #"{"items":[],"lessons":[],"categories":[]}"#
        let fields: [String: Any] = [
            "schemaVersion": ["integerValue": "1"],
            "version": ["stringValue": String(repeating: "a", count: 64)],
            "catalogJSON": ["stringValue": json], "images": ["arrayValue": [:]],
        ]
        let document = try JSONSerialization.data(withJSONObject: ["fields": fields])
        let release = try PublicContentREST.decode(document)
        XCTAssertEqual(release.images, [])
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = PublicContentCache(directory: folder)
        try cache.install(release, images: [:])
        XCTAssertEqual(cache.load(), release)
        var malformed = fields
        malformed["images"] = ["arrayValue": ["values": "invalid"]]
        XCTAssertThrowsError(try PublicContentREST.decode(JSONSerialization.data(withJSONObject: ["fields": malformed])))
    }

    @MainActor func testFirstLoadPublishesLoadingThenSuccessIncludingEmptyContent() async {
        let loader = PublicContentLoader<[String]>()
        XCTAssertEqual(loader.state, .idle)
        XCTAssertNil(loader.current)
        var states: [PublicContentLoadState] = []
        loader.onChange = { states.append(loader.state) }
        await loader.refresh {
            XCTAssertEqual(loader.state, .loading)
            return []
        }
        XCTAssertEqual(states, [.loading, .loaded])
        XCTAssertEqual(loader.current, [])
    }

    @MainActor func testFailureCanRetryImmediatelyAndKeepsCacheUntilSuccess() async {
        let loader = PublicContentLoader(cached: ["cached"])
        XCTAssertEqual(loader.state, .loaded)
        await loader.refresh { throw URLError(.notConnectedToInternet) }
        XCTAssertEqual(loader.state, .failed)
        XCTAssertEqual(loader.current, ["cached"])
        var attempts = 0
        await loader.refresh(force: true) { attempts += 1; return ["new"] }
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(loader.current, ["new"])
        XCTAssertEqual(loader.state, .loaded)
    }

    @MainActor func testFirstFailureEndsLoadingWithoutInventingContent() async {
        let loader = PublicContentLoader<[String]>()
        await loader.refresh { throw URLError(.timedOut) }
        XCTAssertEqual(loader.state, .failed)
        XCTAssertNil(loader.current)
        await loader.refresh(force: true) { [] }
        XCTAssertEqual(loader.state, .loaded)
        XCTAssertEqual(loader.current, [])
    }

    @MainActor func testConcurrentRefreshAndAutomaticCooldownDoNotDuplicateWork() async {
        let loader = PublicContentLoader<[String]>()
        var attempts = 0
        await loader.refresh {
            attempts += 1
            await loader.refresh(force: true) { attempts += 1; return ["duplicate"] }
            return ["first"]
        }
        await loader.refresh { attempts += 1; return [] }
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(loader.current, ["first"])
    }
}
