import Foundation
import XCTest
@testable import CoastWildCore

final class VersionOneBoundaryTests: XCTestCase {
    func testFormerPurchaseTopicsAreUnknown() throws {
        let removed = ["OpenAppPurchase", "LogPurchase", "onCreateOrder", "GetProductPrice", "openVipService", "recharge", "UpdateCoins"]
        let handler = BoundaryHandler()
        let router = BridgeRouter(allowedHosts: ["h5.example.com"], handler: handler)
        for name in removed {
            XCTAssertFalse(BridgeTopic.allCases.map(\.rawValue).contains(name), name)
            XCTAssertNil(BridgeTopic(rawValue: name), name)
            XCTAssertThrowsError(try router.route(name: name, body: nil, sourceURL: URL(string: "https://h5.example.com"), isMainFrame: true)) {
                XCTAssertEqual($0 as? BridgeError, .unknownTopic(name))
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

private final class BoundaryHandler: BridgeMessageHandling {
    func handle(_ message: BridgeMessage) { XCTFail("Removed topic was dispatched") }
}
