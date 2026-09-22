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

    func testStagingDoesNotOverwritePendingOrderForSameProduct() {
        XCTAssertTrue(mapping.stage(orderID: "order-a", forProductID: "monthly"))
        XCTAssertFalse(mapping.stage(orderID: "order-b", forProductID: "monthly"))
        XCTAssertTrue(mapping.stage(orderID: "order-yearly", forProductID: "yearly"))

        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-monthly", productID: "monthly"), "order-a")
        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-yearly", productID: "yearly"), "order-yearly")
    }

    func testRetryReusesPersistedPendingOrderWithoutOwningIt() {
        let first = mapping.prepareAttempt(orderID: "order-a", forProductID: "monthly")
        XCTAssertEqual(first.orderID, "order-a")
        XCTAssertTrue(first.ownsPendingMapping)

        let reloaded = PurchaseOrderMappingStore(defaults: defaults)
        let retry = reloaded.prepareAttempt(orderID: "order-b", forProductID: "monthly")
        XCTAssertEqual(retry.orderID, "order-a")
        XCTAssertFalse(retry.ownsPendingMapping)
        // A pending result performs no cleanup. Another retry must still use A.
        let later = reloaded.prepareAttempt(orderID: "order-c", forProductID: "monthly")
        XCTAssertEqual(later.orderID, "order-a")
        XCTAssertFalse(later.ownsPendingMapping)
    }

    func testCancelledOrThrownRetryPreservesOriginalPendingOrder() {
        _ = mapping.prepareAttempt(orderID: "order-a", forProductID: "monthly")
        let cancelledRetry = mapping.prepareAttempt(orderID: "order-b", forProductID: "monthly")
        mapping.abandonAttempt(cancelledRetry)
        let thrownRetry = mapping.prepareAttempt(orderID: "order-c", forProductID: "monthly")
        XCTAssertEqual(thrownRetry.orderID, "order-a")
        XCTAssertFalse(thrownRetry.ownsPendingMapping)
        mapping.abandonAttempt(thrownRetry)

        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-delayed", productID: "monthly"), "order-a")
    }

    func testVerifiedRetryAssociatesOriginalOrderAndAllowsFreshAttempt() {
        _ = mapping.prepareAttempt(orderID: "order-a", forProductID: "monthly")
        let retry = mapping.prepareAttempt(orderID: "order-b", forProductID: "monthly")
        mapping.completeAttempt(retry, transactionID: "tx-retry")

        XCTAssertEqual(mapping.orderID(forTransactionID: "tx-retry"), "order-a")
        XCTAssertNil(mapping.resolveForUpdate(transactionID: "tx-other", productID: "monthly"))
        let fresh = mapping.prepareAttempt(orderID: "order-c", forProductID: "monthly")
        XCTAssertEqual(fresh.orderID, "order-c")
        XCTAssertTrue(fresh.ownsPendingMapping)
    }

    func testOwningAttemptCleanupAllowsAnotherFreshAttempt() {
        let cancelled = mapping.prepareAttempt(orderID: "order-a", forProductID: "monthly")
        mapping.abandonAttempt(cancelled)
        let thrown = mapping.prepareAttempt(orderID: "order-b", forProductID: "monthly")
        XCTAssertEqual(thrown.orderID, "order-b")
        XCTAssertTrue(thrown.ownsPendingMapping)
        mapping.abandonAttempt(thrown)
        XCTAssertNil(mapping.resolveForUpdate(transactionID: "tx-later", productID: "monthly"))
    }

    func testStaleAttemptCleanupDoesNotClearNewPendingOrder() {
        let first = mapping.prepareAttempt(orderID: "order-a", forProductID: "monthly")
        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-first", productID: "monthly"), "order-a")
        let fresh = mapping.prepareAttempt(orderID: "order-c", forProductID: "monthly")
        XCTAssertTrue(fresh.ownsPendingMapping)

        mapping.abandonAttempt(first)
        mapping.completeAttempt(first, transactionID: "tx-first")
        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-new", productID: "monthly"), "order-c")
        XCTAssertEqual(mapping.orderID(forTransactionID: "tx-first"), "order-a")
    }

    func testExistingTransactionMappingWinsWithoutConsumingPendingOrder() {
        mapping.stage(orderID: "new-order", forProductID: "monthly")
        mapping.associate(orderID: "old-order", transactionID: "tx-old")

        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-old", productID: "monthly"), "old-order")
        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-new", productID: "monthly"), "new-order")
    }

    func testExistingTransactionMappingRecoversMatchingPendingOrderAfterCrash() {
        mapping.stage(orderID: "order-pending", forProductID: "monthly")
        mapping.associate(orderID: "order-pending", transactionID: "tx-1")

        XCTAssertEqual(mapping.resolveForUpdate(transactionID: "tx-1", productID: "monthly"), "order-pending")
        XCTAssertNil(mapping.resolveForUpdate(transactionID: "tx-2", productID: "monthly"))
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
