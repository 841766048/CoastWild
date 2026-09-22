import Foundation
import XCTest
@testable import CoastWildCore

final class PurchaseOrderMappingStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var mapping: PurchaseOrderMappingStore!

    override func setUp() {
        super.setUp()
        suiteName = "PurchaseOrderMappingStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        mapping = PurchaseOrderMappingStore(defaults: defaults, keyPrefix: "com.coastwild.iap.order.")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        mapping = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPendingOrderMigratesToTransactionAndIsConsumed() {
        mapping.stage(orderID: "order-pending", forProductID: "monthly")

        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-1", productID: "monthly"), "order-pending")
        XCTAssertEqual(mapping.orderID(forTransactionID: "tx-1"), "order-pending")
        XCTAssertNil(mapping.resolveForUpdate(transactionID: "tx-2", productID: "monthly"))
    }

    func testCancelPendingRemovesStagedOrder() {
        mapping.stage(orderID: "order-pending", forProductID: "monthly")
        mapping.cancelPending(productID: "monthly")

        XCTAssertNil(mapping.resolveForUpdate(transactionID: "tx-1", productID: "monthly"))
    }

    func testExistingTransactionMappingWinsWithoutConsumingPendingOrder() {
        mapping.stage(orderID: "new-order", forProductID: "monthly")
        mapping.associate(orderID: "old-order", transactionID: "tx-old")

        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-old", productID: "monthly"), "old-order")
        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-new", productID: "monthly"), "new-order")
    }

    func testRestoreLookupAndFinishAllowMissingMapping() {
        XCTAssertNil(mapping.orderID(forTransactionID: "unknown"))
        XCTAssertEqual(
            mapping.restoredTransaction(productID: "monthly", transactionID: "unknown", signedData: "signed"),
            StoreTransaction(productID: "monthly", transactionID: "unknown", signedData: "signed", orderID: nil)
        )

        mapping.associate(orderID: "order-1", transactionID: "tx-1")
        mapping.finish(transactionID: "tx-1")

        XCTAssertNil(mapping.orderID(forTransactionID: "tx-1"))
    }
}
