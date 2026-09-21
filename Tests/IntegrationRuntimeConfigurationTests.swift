import XCTest
@testable import CoastWildCore

final class IntegrationRuntimeConfigurationTests: XCTestCase {
    func testPackageSpecificValuesReplaceAllDefaults() async throws {
        let store = IntegrationRuntimeConfiguration(environment: try makeEnvironment())
        let configuration = try JSONValue(any: [
            "items": [[
                "name": "app_ext_data",
                "data": [
                    "test.duckegg.ios:privacy": "https://remote.example/privacy",
                    "test.duckegg.ios:terms": "https://remote.example/terms",
                    "test.duckegg.ios:app_id": "99887766",
                    "test.duckegg.ios:aj_token": "remote-adjust",
                    "test.duckegg.ios:aj_purchase_token": "remote-purchase",
                    "other.bundle:app_id": "must-not-apply",
                ],
            ]],
        ])

        await store.apply(configuration: configuration)
        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.privacyURL.absoluteString, "https://remote.example/privacy")
        XCTAssertEqual(snapshot.termsURL.absoluteString, "https://remote.example/terms")
        XCTAssertEqual(snapshot.appID, "99887766")
        XCTAssertEqual(snapshot.adjustToken, "remote-adjust")
        XCTAssertEqual(snapshot.adjustPurchaseToken, "remote-purchase")
    }

    func testInvalidAndEmptyValuesFallBackIndependently() async throws {
        let store = IntegrationRuntimeConfiguration(environment: try makeEnvironment())
        let configuration = try JSONValue(any: [
            "items": [[
                "name": "app_ext_data",
                "data": [
                    "test.duckegg.ios:privacy": "http://insecure.example/privacy",
                    "test.duckegg.ios:terms": "not-a-url",
                    "test.duckegg.ios:app_id": "  ",
                    "test.duckegg.ios:aj_token": "valid-token",
                    "test.duckegg.ios:aj_purchase_token": NSNull(),
                ],
            ]],
        ])

        await store.apply(configuration: configuration)
        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.privacyURL.absoluteString, "https://bundled.example/privacy")
        XCTAssertEqual(snapshot.termsURL.absoluteString, "https://bundled.example/terms")
        XCTAssertEqual(snapshot.appID, "123456")
        XCTAssertEqual(snapshot.adjustToken, "valid-token")
        XCTAssertEqual(snapshot.adjustPurchaseToken, "bundled-purchase")
    }

    func testMalformedPayloadLeavesBundledDefaults() async throws {
        let environment = try makeEnvironment()
        let store = IntegrationRuntimeConfiguration(environment: environment)

        await store.apply(configuration: .object(["items": .string("invalid")]))
        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot, IntegrationRuntimeSnapshot(environment: environment))
    }

    func testSecondResponseResetsOmittedValuesToBundledDefaults() async throws {
        let store = IntegrationRuntimeConfiguration(environment: try makeEnvironment())
        await store.apply(configuration: try JSONValue(any: [
            "items": [[
                "name": "app_ext_data",
                "data": ["test.duckegg.ios:aj_token": "first-token"],
            ]],
        ]))
        let firstSnapshot = await store.snapshot()
        XCTAssertEqual(firstSnapshot.adjustToken, "first-token")

        await store.apply(configuration: try JSONValue(any: [
            "items": [["name": "app_ext_data", "data": [:]]],
        ]))
        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.adjustToken, "bundled-adjust")
    }

    private func makeEnvironment() throws -> IntegrationEnvironment {
        try IntegrationEnvironment(
            mode: .development,
            primaryHost: "https://api.example.com",
            webHost: "https://web.example.com",
            imHost: "https://im.example.com",
            logHost: "https://log.example.com",
            privacyURL: "https://bundled.example/privacy",
            termsURL: "https://bundled.example/terms",
            appStoreID: "123456",
            bundleIdentifier: "test.duckegg.ios",
            adjustToken: "bundled-adjust",
            adjustPurchaseToken: "bundled-purchase"
        )
    }
}
