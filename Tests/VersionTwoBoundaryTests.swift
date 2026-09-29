import Foundation
import XCTest
@testable import CoastWildCore

final class VersionTwoBoundaryTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    func testBusinessWebBridgeTrackingCatalogAndCoinsRemainAvailable() throws {
        let required = [
            "CoastWild/UI/BusinessWebController.swift", "CoastWild/UI/InternalWebController.swift",
            "CoastWild/Core/BusinessWebBootstrap.swift", "CoastWild/Core/BusinessWebEntry.swift",
            "CoastWild/Core/BridgeRouter.swift", "CoastWild/App/AttributionAdapters.swift",
            "CoastWild/Core/AttributionCoordinator.swift", "CoastWild/Core/AttributionSubmission.swift",
            "CoastWild/App/StoreKit2PurchaseStore.swift", "CoastWild/Core/IAPBridgeHandler.swift",
            "CoastWild/UI/CoinPurchaseController.swift", "CoastWild/Core/LocalCoinWallet.swift"
        ]
        for path in required {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), path)
        }
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf:
            root.appendingPathComponent("CoastWild/Resources/catalog.json"))) as? [String: Any]
        XCTAssertFalse(try XCTUnwrap(catalog?["items"] as? [Any]).isEmpty)
        XCTAssertFalse(try XCTUnwrap(catalog?["lessons"] as? [Any]).isEmpty)
        XCTAssertEqual(BridgeTopic.allCases.count, 19)
        XCTAssertNotNil(BridgeTopic(rawValue: "OpenAppPurchase"))
        XCTAssertNotNil(BridgeTopic(rawValue: "OpenInternalWeb"))
        let app = try String(contentsOf: root.appendingPathComponent("CoastWild/App/AppDelegate.swift"))
        for call in ["BusinessWebController(", "iapBridgeHandler: iapBridgeHandler", "AdjustAttributionAdapter(",
                     "SystemTrackingAuthorizationAdapter()", "startPurchaseUpdates()", "startAttribution(userID:"] {
            XCTAssertTrue(app.contains(call), call)
        }
        let pods = try String(contentsOf: root.appendingPathComponent("Podfile"))
        XCTAssertTrue(pods.contains("pod 'Adjust'"))
        let project = try String(contentsOf: root.appendingPathComponent("project.yml"))
        XCTAssertTrue(project.contains("NSUserTrackingUsageDescription"))
    }

    func testDevelopmentConfigurationUsesBackendPackageWithoutChangingInstalledIdentity() async throws {
        let environment = try environment(mode: .development)
        let runtime = IntegrationRuntimeConfiguration(environment: environment)
        await runtime.apply(configuration: try JSONValue(any: ["items": [[
            "name": "app_ext_data", "data": [
                "test.duckegg.ios:privacy": "https://remote.example/privacy",
                "test.duckegg.ios:aj_token": "test-adjust",
                "test.duckegg.ios:aj_purchase_token": "test-purchase"
            ]
        ]]]))
        let value = await runtime.snapshot()
        XCTAssertEqual(value.privacyURL.absoluteString, "https://remote.example/privacy")
        XCTAssertEqual(value.adjustToken, "test-adjust")
        XCTAssertEqual(value.adjustPurchaseToken, "test-purchase")
        XCTAssertEqual(environment.bundleIdentifier, "com.example.installed")
    }

    func testReleaseConfigurationKeepsItsOwnPackage() async throws {
        let runtime = IntegrationRuntimeConfiguration(environment: try environment(mode: .release))
        await runtime.apply(configuration: try JSONValue(any: ["items": [[
            "name": "app_ext_data", "data": [
                "test.duckegg.ios:aj_token": "wrong-token",
                "com.example.installed:aj_token": "release-adjust"
            ]
        ]]]))
        let value = await runtime.snapshot()
        XCTAssertEqual(value.adjustToken, "release-adjust")
    }

    private func environment(mode: IntegrationEnvironment.Mode) throws -> IntegrationEnvironment {
        try IntegrationEnvironment(mode: mode, primaryHost: "https://api.example", webHost: "https://web.example",
            imHost: "https://im.example", logHost: "https://log.example", privacyURL: "https://web.example/privacy",
            termsURL: "https://web.example/terms", appStoreID: "123", bundleIdentifier: "com.example.installed")
    }
}
