import Foundation
import XCTest
@testable import CoastWildCore

final class VersionOneBoundaryTests: XCTestCase {
    func testNativeVersionExcludesWebTrackingAndBundledCatalog() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let production = root.appendingPathComponent("CoastWild")
        XCTAssertFalse(FileManager.default.fileExists(atPath: production.appendingPathComponent("Resources/catalog.json").path))
        let files = try XCTUnwrap(FileManager.default.enumerator(at: production, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file)
            for token in ["BusinessWeb", "BridgeRouter", "WKScriptMessageHandler", "AdjustSdk", "ATTrackingManager", "AttributionCoordinator", "getStrategy", "attribution_sdk", "adjustToken"] {
                XCTAssertFalse(source.contains(token), "\(file.lastPathComponent): \(token)")
            }
        }
        for path in ["Podfile", "Podfile.lock", "project.yml", "CoastWild.xcodeproj/project.pbxproj"] {
            let source = try String(contentsOf: root.appendingPathComponent(path))
            for token in ["Adjust", "NSUserTrackingUsageDescription", "catalog.json", "BusinessWeb"] {
                XCTAssertFalse(source.contains(token), "\(path): \(token)")
            }
        }
    }
    func testProductionContainsNoPurchaseImplementationOrConfiguration() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let production = root.appendingPathComponent("CoastWild")
        let forbidden = ["StoreKit", "PurchaseCoordinator", "IAPBridgeHandler", "IntegrationPurchaseServer", "ProductCatalog", "PurchaseOrderMappingStore", "ReceiptVerificationRequest", "RechargeRequest", "createRecharge", "paymentRecharge", "verifyReceipt", "restorePurchases", "trackPurchase", "setRevenue", "adjustPurchaseToken", "CoastAdjustPurchaseToken", "aj_purchase_token", "account.restore-purchases", "OpenAppPurchase", "LogPurchase", "onCreateOrder", "GetProductPrice", "openVipService", "recharge", "UpdateCoins", "iapLog", "EntitlementSnapshot", "购买", "Apple subscription", "Apple 订阅"]
        let files = try XCTUnwrap(FileManager.default.enumerator(at: production, includingPropertiesForKeys: nil))
        for case let file as URL in files where ["swift", "plist", "strings", "html"].contains(file.pathExtension) {
            let text = try String(contentsOf: file, encoding: .utf8)
            for token in forbidden {
                XCTAssertFalse(text.contains(token), "\(file.lastPathComponent) contains \(token)")
            }
        }
    }
}
