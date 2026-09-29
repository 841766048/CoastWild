import XCTest
@testable import CoastWildCore

final class PublicContentTests: XCTestCase {
    private func restData(_ release: PublicContentRelease) throws -> Data {
        func value(_ object: Any) -> [String: Any] {
            if let text = object as? String { return ["stringValue": text] }
            if let number = object as? Int { return ["integerValue": String(number)] }
            if let array = object as? [Any] { return ["arrayValue": ["values": array.map(value)]] }
            let fields = object as! [String: Any]
            return ["mapValue": ["fields": fields.mapValues(value)]]
        }
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(release)) as! [String: Any]
        return try JSONSerialization.data(withJSONObject: ["fields": object.mapValues(value)])
    }

    func testRESTDocumentDecodesAndValidatesRelease() throws {
        let release = try fixture()
        XCTAssertEqual(try PublicContentREST.decode(restData(release)), release)
        XCTAssertThrowsError(try PublicContentREST.decode(Data("{}".utf8)))
        var invalid = release; invalid.schemaVersion = 2
        XCTAssertThrowsError(try PublicContentREST.decode(restData(invalid)))
    }

    func testRESTRequestUsesFixedHTTPSDocumentAndBearerHeader() throws {
        let request = try PublicContentREST.request(token: "test-token")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://firestore.googleapis.com/v1/projects/coast-wild-20260915/databases/(default)/documents/publicCatalog/current")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertNil(request.url?.query)
        XCTAssertThrowsError(try PublicContentREST.request(token: ""))
        XCTAssertThrowsError(try PublicContentREST.request(token: "bad\r\nheader"))
    }

    func testRESTRetriesUnauthorizedOnceWithFreshToken() async throws {
        var refreshes: [Bool] = []
        var requests = 0
        let data = try restData(fixture())
        let result = try await PublicContentREST.fetch(token: { force in
            refreshes.append(force); return "test-token"
        }, send: { _ in
            requests += 1
            return (requests == 1 ? 401 : 200, data)
        })
        XCTAssertEqual(refreshes, [false, true])
        XCTAssertEqual(requests, 2)
        XCTAssertEqual(result, try fixture())
    }

    func testRESTStopsOnForbiddenRepeatedUnauthorizedAndTransportFailure() async throws {
        for status in [401, 403, 404, 500] {
            var requests = 0
            do {
                _ = try await PublicContentREST.fetch(token: { _ in "token" }, send: { _ in
                    requests += 1; return (status, Data())
                })
                XCTFail("Must reject HTTP \(status)")
            } catch { XCTAssertEqual(error as? PublicContentREST.Failure, .http(status)) }
            XCTAssertEqual(requests, status == 401 ? 2 : 1)
        }
        do {
            _ = try await PublicContentREST.fetch(token: { _ in "token" }, send: { _ in
                throw URLError(.timedOut)
            })
            XCTFail("Must propagate timeout")
        } catch { XCTAssertEqual((error as? URLError)?.code, .timedOut) }
    }

    private final class ThreadProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [Bool] = []

        func record() { lock.lock(); values.append(Thread.isMainThread); lock.unlock() }
        var observedMainThread: Bool {
            lock.lock(); defer { lock.unlock() }
            return values.contains(true)
        }
    }

    func testPublisherManifestWhenProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["COAST_PUBLIC_MANIFEST"] else {
            throw XCTSkip("Set COAST_PUBLIC_MANIFEST for publisher/client contract verification")
        }
        let release = try JSONDecoder().decode(PublicContentRelease.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertNoThrow(try release.validate())
    }
    private func fixture() throws -> PublicContentRelease {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let json = try String(contentsOf: root.appendingPathComponent("Tests/Fixtures/public-catalog.json"))
        let names = try PublicContentRelease.referencedImages(in: Data(json.utf8))
        let version = String(repeating: "a", count: 64)
        return PublicContentRelease(schemaVersion: 1, version: version, catalogJSON: json,
            images: names.sorted().map { .init(name: $0, path: "content/\(version)/images/\($0).jpg", sha256: PublicContentRelease.digest(Data([1, 2, 3])), bytes: 3) })
    }

    func testValidCatalogAndExactImageManifest() throws {
        let release = try fixture()
        XCTAssertNoThrow(try release.validate())
        XCTAssertGreaterThan(release.images.count, 10)
        var missing = release; missing.images.removeLast()
        XCTAssertThrowsError(try missing.validate())
        var duplicate = release; duplicate.images.append(release.images[0])
        XCTAssertThrowsError(try duplicate.validate())
    }

    func testRejectsTraversalForeignVersionAndInvalidCatalog() throws {
        var release = try fixture()
        release.images[0].path = "../private.jpg"
        XCTAssertThrowsError(try release.validate())
        release = try fixture(); release.version = "../../notes"
        XCTAssertThrowsError(try release.validate())
        release = try fixture(); release.catalogJSON = "{}"
        XCTAssertThrowsError(try release.validate())
        release = try fixture(); release.images[0].bytes = 9 * 1024 * 1024
        XCTAssertThrowsError(try release.validate())
    }

    func testAtomicCachePreservesLastGoodReleaseOnIncompleteOrBadDownload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = PublicContentCache(directory: folder)
        XCTAssertNil(cache.load())
        let release = try fixture()
        let bytes = Dictionary(uniqueKeysWithValues: release.images.map { ($0.name, Data([1, 2, 3])) })
        try cache.install(release, images: bytes)
        XCTAssertEqual(cache.load()?.version, release.version)
        XCTAssertThrowsError(try cache.install(release, images: [:]))
        var corrupt = bytes; corrupt[release.images[0].name] = Data([9, 9, 9])
        XCTAssertThrowsError(try cache.install(release, images: corrupt))
        XCTAssertEqual(cache.load()?.version, release.version)
        let reopened = PublicContentCache(directory: folder)
        XCTAssertEqual(reopened.load()?.version, release.version)
        let imageURL = try XCTUnwrap(reopened.imageURL(named: release.images[0].name, release: release))
        try Data([0]).write(to: imageURL)
        XCTAssertNil(reopened.load(), "Corrupt cached images must be rejected")
    }

    @MainActor func testWorkerPerformsValidationAndInstallationOffMainAndKeepsOldCacheOnFetchFailure() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = PublicContentCache(directory: folder)
        let release = try fixture()
        let bytes = Dictionary(uniqueKeysWithValues: release.images.map { ($0.name, Data([1, 2, 3])) })
        try cache.install(release, images: bytes)

        var replacement = release
        replacement.version = String(repeating: "b", count: 64)
        replacement.images = replacement.images.map {
            .init(name: $0.name,
                  path: "content/\(String(repeating: "b", count: 64))/images/\($0.name).jpg",
                  sha256: $0.sha256,
                  bytes: $0.bytes)
        }
        let probe = ThreadProbe()
        let worker = PublicContentWorker(cache: cache)
        let failingName = replacement.images.last!.name

        do {
            _ = try await worker.fetchAndInstall(replacement, fetch: { image in
                probe.record()
                if image.name == failingName { throw PublicContentError.invalidImage }
                return Data([1, 2, 3])
            }, validateImage: { _ in
                probe.record()
                return true
            })
            XCTFail("Expected the incomplete fetch to fail")
        } catch {}

        XCTAssertFalse(probe.observedMainThread)
        XCTAssertEqual(cache.load()?.version, release.version)
    }
}
