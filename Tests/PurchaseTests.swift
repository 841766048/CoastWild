import XCTest
@testable import CoastWildCore

final class PurchaseTests: XCTestCase {
    func testCatalogReturnsLocalizedPricesAndReportsMissingSKUs() async throws {
        let store = PurchaseStoreFake(products: [
            .init(id: "monthly", displayName: "Monthly", displayPrice: "$4.99", currencyCode: "USD", subscriptionPeriod: "P1M"),
            .init(id: "coins", displayName: "100 Coins", displayPrice: "¥30", currencyCode: "CNY", subscriptionPeriod: nil),
        ])
        let result = try await ProductCatalog(store: store).load(productIDs: ["monthly", "missing", "coins"])
        XCTAssertEqual(result.products.map(\.id), ["monthly", "coins"])
        XCTAssertEqual(result.products.map(\.displayPrice), ["$4.99", "¥30"])
        XCTAssertEqual(result.products.map(\.currencyCode), ["USD", "CNY"])
        XCTAssertEqual(result.missingProductIDs, ["missing"])
        XCTAssertEqual(result.bridgeValue, .object(["data": .array([
            .object(["id": .string("monthly"), "localPrice": .string("$4.99"), "currencyCode": .string("USD")]),
            .object(["id": .string("coins"), "localPrice": .string("¥30"), "currencyCode": .string("CNY")]),
        ])]))
    }

    func testPurchaseStopsAtEachFailureAndOnlyFinishesAfterVerification() async throws {
        for scenario in PurchaseScenario.allCases {
            let events = EventLog()
            let store = PurchaseStoreFake(products: [], scenario: scenario, events: events)
            let server = PurchaseServerFake(scenario: scenario, events: events)
            let entitlements = EntitlementStore()
            let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: entitlements)
            do {
                let result = try await coordinator.purchase(.init(productID: "monthly", paySource: "profile", invitationID: ""))
                if scenario == .cancelled { XCTAssertEqual(result, .cancelled) }
                else if scenario == .pending { XCTAssertEqual(result, .pending) }
                else if scenario != .success { XCTFail("expected error for \(scenario)") }
                else { XCTAssertEqual(result, .purchased(.init(productID: "monthly", isActive: true))) }
            } catch {
                XCTAssertNotEqual(scenario, .success)
                XCTAssertNotEqual(scenario, .cancelled)
                XCTAssertNotEqual(scenario, .pending)
            }
            let recorded = await events.values
            switch scenario {
            case .orderFailure: XCTAssertEqual(recorded, ["order"])
            case .cancelled, .pending, .unverified: XCTAssertEqual(recorded, ["order", "purchase"])
            case .verificationFailure: XCTAssertEqual(recorded, ["order", "purchase", "verify"])
            case .success: XCTAssertEqual(recorded, ["order", "purchase", "verify", "finish"])
            }
            let snapshot = await entitlements.snapshot()
            XCTAssertEqual(snapshot.isActive, scenario == .success)
        }
    }

    func testStructuredLogNeverContainsReceipt() {
        let log = PurchaseLog(stage: .verificationFailed, productID: "monthly", transactionID: "tx-1", errorCode: "network")
        let object = log.jsonValue.foundationObject as! [String: Any]
        XCTAssertNil(object["receipt"])
        XCTAssertEqual(object["transactionId"] as? String, "tx-1")
    }

    func testRestoreVerifiesMultipleTransactionsAndRefreshesEntitlements() async throws {
        let events = EventLog()
        let store = PurchaseStoreFake(products: [], restored: [
            .init(productID: "monthly", transactionID: "tx-1", signedData: "secret-one", orderID: "order-1"),
            .init(productID: "yearly", transactionID: "tx-2", signedData: "secret-two", orderID: "order-2"),
        ], events: events)
        let server = PurchaseServerFake(scenario: .success, events: events)
        let entitlements = EntitlementStore()
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: entitlements)
        let restored = try await coordinator.restorePurchases()
        XCTAssertEqual(Set(restored.map(\.productID)), ["monthly", "yearly"])
        let entitlement = await entitlements.snapshot()
        let finished = await store.finishedTransactionIDs()
        XCTAssertTrue(entitlement.isActive)
        XCTAssertEqual(Set(finished), ["tx-1", "tx-2"])
    }

    func testTransactionUpdatesAreVerifiedAndFinished() async {
        let transaction = StoreTransaction(productID: "monthly", transactionID: "tx-update", signedData: "secret", orderID: "order-update")
        let store = PurchaseStoreFake(products: [], restored: [transaction])
        let server = PurchaseServerFake(scenario: .success, events: EventLog())
        let entitlements = EntitlementStore()
        let coordinator = PurchaseCoordinator(store: store, server: server, entitlements: entitlements)
        await coordinator.observeTransactionUpdates()
        let finished = await store.finishedTransactionIDs()
        let entitlement = await entitlements.snapshot()
        XCTAssertEqual(finished, ["tx-update"])
        XCTAssertTrue(entitlement.isActive)
    }
}

private enum PurchaseScenario: CaseIterable { case orderFailure, cancelled, pending, unverified, verificationFailure, success }
private enum FakeError: Error { case failed }
private actor EventLog { var values: [String] = []; func add(_ value: String) { values.append(value) } }

private actor PurchaseStoreFake: PurchaseStoreProviding {
    let products: [StoreProduct]
    let scenario: PurchaseScenario
    let restored: [StoreTransaction]
    let events: EventLog
    private var finished: [String] = []
    init(products: [StoreProduct], scenario: PurchaseScenario = .success, restored: [StoreTransaction] = [], events: EventLog = EventLog()) {
        self.products = products; self.scenario = scenario; self.restored = restored; self.events = events
    }
    func products(for ids: [String]) async throws -> [StoreProduct] { products.filter { ids.contains($0.id) } }
    func purchase(productID: String, orderID: String) async throws -> StorePurchaseResult {
        await events.add("purchase")
        switch scenario { case .cancelled: return .cancelled; case .pending: return .pending; case .unverified: return .unverified; default: return .verified(.init(productID: productID, transactionID: "tx-1", signedData: "top-secret-receipt", orderID: orderID)) }
    }
    func finish(transactionID: String) async { await events.add("finish"); finished.append(transactionID) }
    func restore() async throws -> [StoreTransaction] { restored }
    func transactionUpdates() async -> AsyncStream<StoreTransaction> {
        let restored = self.restored
        return AsyncStream<StoreTransaction>(bufferingPolicy: .unbounded) { continuation in
            for transaction in restored {
                continuation.yield(transaction)
            }
            continuation.finish()
        }
    }
    func finishedTransactionIDs() -> [String] { finished }
}

private actor PurchaseServerFake: PurchaseServerProviding {
    let scenario: PurchaseScenario; let events: EventLog
    init(scenario: PurchaseScenario, events: EventLog) { self.scenario = scenario; self.events = events }
    func createOrder(_ request: PurchaseRequest) async throws -> PurchaseOrder {
        await events.add("order"); if scenario == .orderFailure { throw FakeError.failed }
        return PurchaseOrder(orderID: "order-1", productID: request.productID)
    }
    func verify(orderID: String?, transaction: StoreTransaction) async throws -> EntitlementSnapshot {
        await events.add("verify"); if scenario == .verificationFailure { throw FakeError.failed }
        return .init(productID: transaction.productID, isActive: true)
    }
}
