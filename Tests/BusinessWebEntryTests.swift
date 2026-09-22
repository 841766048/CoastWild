import XCTest
@testable import CoastWildCore

final class BusinessWebEntryTests: XCTestCase {
    func testCredentialScriptIsRestrictedToTheTrustedOrigin() throws {
        let script = try BusinessWebEntry.restrictScript("window.secret='value';",
            to: URL(string: "https://web.example:8443/app")!)
        XCTAssertTrue(script.contains("window.location.origin === \"https:\\/\\/web.example:8443\""))
        XCTAssertTrue(script.contains("window.secret='value';"))
    }
    func testBootstrapPreservesFullPayloadsAndUsesRemoteLegalURLs() async throws {
        let environment = try IntegrationEnvironment(
            mode: .development, primaryHost: "https://api.example", webHost: "https://web.example",
            imHost: "https://im.example", logHost: "https://log.example",
            privacyURL: "https://web.example/privacy", termsURL: "https://web.example/terms",
            appStoreID: "1", bundleIdentifier: "example.app")
        let runtime = IntegrationRuntimeConfiguration(environment: environment)
        let raw: JSONValue = .object(["k2": .string("k2"), "k3": .string("k3"), "k4": .string("k4"), "extra": .number(1)])
        await runtime.apply(configuration: try JSONValue(any: ["items": [[
            "name": "app_ext_data", "data": ["example.app:privacy": "https://web.example/new-privacy"],
        ]]]), encryptedConfiguration: raw)
        let user: JSONValue = .object(["userId": .string("user"), "nested": .array([.number(1)])])
        let session = try RemoteSession(oauthResponse: .object([
            "token": .string("token"), "userInfo": user, "isFirstRegister": .number(0),
        ]))
        let strategy: JSONValue = .object(["isReviewPkg": .bool(true), "data": .object(["extra": .number(2)])])
        let bootstrap = try BusinessWebEntry.bootstrap(
            environment: environment, runtime: await runtime.snapshot(), session: session,
            strategy: strategy, headers: ["Authorization": "Bearer token"],
            package: .init(localeIdentifier: "en", appName: "App", packageName: "example.app"))
        XCTAssertEqual(bootstrap.encryptedConfiguration, raw)
        XCTAssertEqual(bootstrap.strategy, strategy)
        XCTAssertEqual(bootstrap.userInfo, user)
        XCTAssertEqual(bootstrap.httpHeaders["Authorization"], "Bearer token")
        XCTAssertEqual(bootstrap.baseURLs.privacy, "https://web.example/new-privacy")
    }

    func testURLPriorityReplacesLastSegmentAndPreservesQuery() throws {
        let url = try BusinessWebEntry.url(
            bundled: URL(string: "https://web.example/start")!,
            configured: URL(string: "https://web.example/app/index.html?lang=en&t=old#home")!,
            strategy: .object(["data": .object([
                "webIndexUrl2": .string("next.html"),
                "webIndexUrl": .string("https://web.example/ignored"),
            ])]), timestamp: 123)
        XCTAssertEqual(url.absoluteString, "https://web.example/app/next.html?lang=en&t=123#home")
    }

    func testFullStrategyURLAndReviewFlagDoNotChangeRoutingRules() throws {
        for flag in [true, false] {
            let url = try BusinessWebEntry.url(
                bundled: URL(string: "https://web.example/start")!, configured: nil,
                strategy: .object(["isReviewPkg": .bool(flag), "data": .object([
                    "webIndexUrl": .string("https://web.example/remote"),
                ])]), timestamp: 1)
            XCTAssertEqual(url.absoluteString, "https://web.example/remote?t=1")
        }
    }

    func testEmptyOptionalStrategyURLsFallBack() throws {
        let url = try BusinessWebEntry.url(bundled: URL(string: "https://web.example/start")!,
            configured: nil, strategy: .object(["data": .object([
                "webIndexUrl2": .string(""), "webIndexUrl": .null,
            ])]), timestamp: 1)
        XCTAssertEqual(url.absoluteString, "https://web.example/start?t=1")
    }

    func testUntrustedOrInvalidEntryFailsClosed() {
        for value in ["https://evil.example/token", "http://web.example/start", "https://user:pass@web.example/start"] {
            XCTAssertThrowsError(try BusinessWebEntry.url(
                bundled: URL(string: "https://web.example/start")!, configured: nil,
                strategy: .object(["data": .object(["webIndexUrl": .string(value)])]), timestamp: 1))
        }
        for path in ["../escape", "https://evil.example", "next?query=1", "%2e%2e"] {
            XCTAssertThrowsError(try BusinessWebEntry.url(
                bundled: URL(string: "https://web.example/start")!, configured: nil,
                strategy: .object(["data": .object(["webIndexUrl2": .string(path)])]), timestamp: 1))
        }
    }
}
