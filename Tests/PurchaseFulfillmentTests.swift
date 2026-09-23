import XCTest
@testable import CoastWildCore

final class PurchaseFulfillmentTests: XCTestCase {
    let request = PurchaseRequest(productID: "1coins_19", paySource: "native", invitationID: "")
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
    func setLog(_ value: FulfillmentLog) { log = value }
    func setFail(_ value: Bool) { fail = value }
    func createOrder(_ request: PurchaseRequest) async throws -> PurchaseOrder { .init(orderID: "order", productID: request.productID) }
    func verify(orderID: String?, transaction: StoreTransaction) async throws -> EntitlementSnapshot {
        await log?.add("verify"); if fail { throw FulfillmentFailure.failed }
        return .init(productID: transaction.productID, isActive: true)
    }
}
private actor FulfillmentStore: PurchaseStoreProviding {
    var calls = 0; var log: FulfillmentLog?
    let tx = StoreTransaction(productID: "1coins_19", transactionID: "tx", signedData: "signed", orderID: "order")
    func setLog(_ value: FulfillmentLog) { log = value }
    func products(for ids: [String]) async throws -> [StoreProduct] { [] }
    func purchase(productID: String, orderID: String) async throws -> StorePurchaseResult { calls += 1; return .verified(tx) }
    func finish(transactionID: String) async { await log?.add("finish") }
    func restore() async throws -> [StoreTransaction] { [tx] }
    func transactionUpdates() async -> AsyncStream<StoreTransaction> { AsyncStream { $0.yield(tx); $0.finish() } }
}
