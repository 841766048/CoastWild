import XCTest
@testable import CoastWildCore

final class PurchaseFulfillmentTests: XCTestCase {
    let request = PurchaseRequest(productID: "1coins_19", paySource: "native", invitationID: "")
    func testRelaunchReconcilesUnfinishedBeforeCreatingOrderAndRetryCreditsOnce() async throws {
        let store = FulfillmentStore(), server = FulfillmentServer()
        await store.setUnfinished(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("wallet.json")
        let wallet = LocalCoinWallet(fileURL: url)
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore(), fulfillment: wallet)
        let result = try await coordinator.purchase(request)
        XCTAssertEqual(result, .pending)
        let orders = await server.orders, purchases = await store.calls
        XCTAssertEqual(orders, 0); XCTAssertEqual(purchases, 0)
        _ = try await coordinator.retryPendingPurchases()
        let orderIDs = await server.verifiedOrderIDs
        XCTAssertEqual(orderIDs, [nil])
        let snapshot = try await wallet.snapshot()
        XCTAssertEqual(snapshot.balance, 100); XCTAssertEqual(snapshot.entries.count, 1)
        let finished = await store.finishes
        XCTAssertEqual(finished, 1)
        let after = await coordinator.synchronizePendingPurchases()
        XCTAssertTrue(after.isEmpty)
    }
    func testSynchronizationDoesNotRestageStaleFinishedTransaction() async throws {
        let store = FulfillmentStore(), server = FulfillmentServer()
        await store.setUnfinished(true)
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore())
        let staged = await coordinator.synchronizePendingPurchases()
        XCTAssertEqual(staged.map(\.transactionID), ["tx"])
        await coordinator.observeTransactionUpdates()
        let after = await coordinator.synchronizePendingPurchases()
        XCTAssertTrue(after.isEmpty)
        await coordinator.observeTransactionUpdates()
        let finishes = await store.finishes
        XCTAssertEqual(finishes, 1)
    }
    func testMappedGoodsCodePendingBlocksNewOrderAndApprovalClearsBySKU() async throws {
        let store = FulfillmentStore(), server = FulfillmentServer()
        await server.setSKU("1coins_19"); await store.setPending(true)
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore())
        let goods = PurchaseRequest(productID: "goods-coins", paySource: "bridge", invitationID: "")
        _ = try await coordinator.purchase(goods)
        await store.setPending(false)
        await coordinator.observeTransactionUpdates()
        let pending = await coordinator.pendingPurchases()
        XCTAssertTrue(pending.isEmpty)
        let result = try await coordinator.purchase(goods)
        XCTAssertEqual(result, .purchased(.init(productID: "1coins_19", isActive: true)))
    }
    func testMappedGoodsCodeVerificationFailureBlocksNewOrder() async throws {
        let store = FulfillmentStore(), server = FulfillmentServer()
        await server.setSKU("1coins_19"); await server.setFail(true)
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore())
        let goods = PurchaseRequest(productID: "goods-coins", paySource: "bridge", invitationID: "")
        do { _ = try await coordinator.purchase(goods); XCTFail("expected failure") } catch {}
        do {
            let result = try await coordinator.purchase(goods)
            XCTAssertEqual(result, .pending)
        } catch { XCTFail("should block before verification: \(error)") }
        let orders = await server.orders, purchases = await store.calls
        XCTAssertEqual(orders, 1); XCTAssertEqual(purchases, 1)
    }
    func testInactiveRestoreDoesNotBlockFuturePurchase() async throws {
        let store = FulfillmentStore(), server = FulfillmentServer()
        await server.setActive(false)
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore())
        let restored = try await coordinator.restorePurchases()
        XCTAssertTrue(restored.isEmpty)
        let pending = await coordinator.pendingPurchases()
        XCTAssertTrue(pending.isEmpty)
        await server.setActive(true)
        let result = try await coordinator.purchase(request)
        XCTAssertEqual(result, .purchased(.init(productID: "1coins_19", isActive: true)))
    }
    func testAllPathsVerifyFulfillBeforeFinish() async throws {
        for path in ["purchase", "restore", "update"] {
            let log = FulfillmentLog(), store = FulfillmentStore(), server = FulfillmentServer()
            await store.setLog(log); await server.setLog(log)
            let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore(), fulfillment: log)
            if path == "purchase" { _ = try await coordinator.purchase(request) }
            else if path == "restore" { _ = try await coordinator.restorePurchases() }
            else { await coordinator.observeTransactionUpdates() }
            let events = await log.events
            XCTAssertEqual(events, ["verify", "fulfill", "finish"], path)
        }
    }
    func testFailedFulfillmentRemainsPendingBlocksRepurchaseAndRetries() async throws {
        let log = FulfillmentLog(), store = FulfillmentStore(), server = FulfillmentServer()
        await store.setLog(log); await server.setLog(log); await log.setFail(true)
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore(), fulfillment: log)
        do { _ = try await coordinator.purchase(request); XCTFail("expected failure") } catch {}
        let pending = await coordinator.pendingPurchases()
        XCTAssertEqual(pending.map(\.productID), ["1coins_19"])
        let result = try await coordinator.purchase(request)
        XCTAssertEqual(result, .pending)
        let calls = await store.calls
        XCTAssertEqual(calls, 1)
        let failedEvents = await log.events
        XCTAssertFalse(failedEvents.contains("finish"))
        await log.setFail(false)
        let recovered = try await coordinator.retryPendingPurchases()
        XCTAssertEqual(recovered.count, 1)
        let after = await coordinator.pendingPurchases()
        XCTAssertTrue(after.isEmpty)
        let events = await log.events
        XCTAssertEqual(events, ["verify", "fulfill", "verify", "fulfill", "finish"])
    }
    func testVerificationFailureNeverCreditsAndCanRecover() async throws {
        let log = FulfillmentLog(), store = FulfillmentStore(), server = FulfillmentServer()
        await store.setLog(log); await server.setLog(log); await server.setFail(true)
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore(), fulfillment: log)
        do { _ = try await coordinator.purchase(request); XCTFail("expected failure") } catch {}
        let events = await log.events
        XCTAssertEqual(events, ["verify"])
        await server.setFail(false)
        _ = try await coordinator.retryPendingPurchases()
        let after = await log.events
        XCTAssertEqual(after, ["verify", "verify", "fulfill", "finish"])
    }
    func testRestoreAndUpdateFailuresRemainRetryableWithoutFinish() async throws {
        for path in ["restore", "update"] {
            let log = FulfillmentLog(), store = FulfillmentStore(), server = FulfillmentServer()
            await store.setLog(log); await server.setLog(log); await log.setFail(true)
            let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore(), fulfillment: log)
            if path == "restore" {
                do { _ = try await coordinator.restorePurchases(); XCTFail("expected failure") } catch {}
            } else { await coordinator.observeTransactionUpdates() }
            let pending = await coordinator.pendingPurchases(), events = await log.events
            XCTAssertEqual(pending.map(\.transactionID), ["tx"])
            XCTAssertEqual(events, ["verify", "fulfill"])
            await log.setFail(false)
            _ = try await coordinator.retryPendingPurchases()
            let final = await log.events
            XCTAssertEqual(final.last, "finish")
        }
    }
    func testConcurrentDeliveryAndRelaunchDoNotCreditTwice() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("wallet.json")
        let wallet = LocalCoinWallet(fileURL: url), store = FulfillmentStore(), server = FulfillmentServer()
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore(), fulfillment: wallet)
        async let purchased = coordinator.purchase(request)
        async let restored = coordinator.restorePurchases()
        async let updated: Void = coordinator.observeTransactionUpdates()
        _ = try await (purchased, restored, updated)
        let relaunched = PurchaseCoordinator(store: store, server: server, entitlements: EntitlementStore(), fulfillment: LocalCoinWallet(fileURL: url))
        await relaunched.observeTransactionUpdates()
        let snapshot = try await wallet.snapshot()
        XCTAssertEqual(snapshot.balance, 100); XCTAssertEqual(snapshot.entries.count, 1)
    }
}
private enum FulfillmentFailure: Error { case failed }
private actor FulfillmentLog: PurchaseTransactionFulfilling {
    var events: [String] = []; var fail = false
    func add(_ event: String) { events.append(event) }
    func setFail(_ value: Bool) { fail = value }
    func fulfill(_ transaction: StoreTransaction) async throws { events.append("fulfill"); if fail { throw FulfillmentFailure.failed } }
}
private actor FulfillmentServer: PurchaseServerProviding {
    var log: FulfillmentLog?; var fail = false
    var sku: String?; var active = true; var orders = 0; var verifiedOrderIDs: [String?] = []
    func setSKU(_ value: String) { sku = value }
    func setActive(_ value: Bool) { active = value }
    func setLog(_ value: FulfillmentLog) { log = value }
    func setFail(_ value: Bool) { fail = value }
    func createOrder(_ request: PurchaseRequest) async throws -> PurchaseOrder { orders += 1; return .init(orderID: "order", productID: sku ?? request.productID) }
    func verify(orderID: String?, transaction: StoreTransaction) async throws -> EntitlementSnapshot {
        verifiedOrderIDs.append(orderID)
        await log?.add("verify"); if fail { throw FulfillmentFailure.failed }
        return .init(productID: transaction.productID, isActive: active)
    }
}
private actor FulfillmentStore: PurchaseStoreProviding {
    var calls = 0; var log: FulfillmentLog?
    var unfinished = false; var finishes = 0
    func setUnfinished(_ value: Bool) { unfinished = value }
    // Intentionally stale after finish to model enumeration racing with an observer.
    func unfinishedTransactions() async -> [StoreTransaction] { unfinished ? [tx] : [] }
    var pending = false
    func setPending(_ value: Bool) { pending = value }
    let tx = StoreTransaction(productID: "1coins_19", transactionID: "tx", signedData: "signed", orderID: nil)
    func setLog(_ value: FulfillmentLog) { log = value }
    func products(for ids: [String]) async throws -> [StoreProduct] { [] }
    func purchase(productID: String, orderID: String) async throws -> StorePurchaseResult { calls += 1; return pending ? .pending : .verified(tx) }
    func finish(transactionID: String) async { finishes += 1; await log?.add("finish") }
    func restore() async throws -> [StoreTransaction] { [tx] }
    func transactionUpdates() async -> AsyncStream<StoreTransaction> { AsyncStream { $0.yield(tx); $0.finish() } }
}
