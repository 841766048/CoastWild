import XCTest
@testable import CoastWildCore

final class IAPBridgeHandlerTests: XCTestCase {
    func testPriceMessageReturnsDocumentedBridgePayload() async throws {
        let fixture = makeFixture(products: [
            .init(id: "monthly", displayName: "Monthly", displayPrice: "$4.99", currencyCode: "USD", subscriptionPeriod: "P1M")
        ])

        let commands = try await fixture.handler.handle(.getProductPrice(["monthly"]))

        XCTAssertEqual(commands, [.productPrices(.object(["data": .array([
            .object(["id": .string("monthly"), "localPrice": .string("$4.99"), "currencyCode": .string("USD")])
        ])]))])
    }

    func testPurchaseOutcomesReturnReceiptFreeStableLogs() async throws {
        for scenario in BridgePurchaseScenario.allCases {
            let fixture = makeFixture(scenario: scenario)
            let commands = try await fixture.handler.handle(.openAppPurchase(.init(
                goodsCode: "monthly", paySource: "profile", invitationID: "invite"
            )))
            XCTAssertEqual(commands.count, 1)
            guard case let .iapLog(value) = commands[0],
                  let object = value.foundationObject as? [String: Any] else {
                return XCTFail("Expected IAP log command")
            }
            XCTAssertEqual(object["productId"] as? String, "monthly")
            XCTAssertEqual(object["status"] as? String, scenario.status)
            let encoded = try JSONSerialization.data(withJSONObject: object)
            let text = String(decoding: encoded, as: UTF8.self)
            XCTAssertFalse(text.contains("signed-secret"))
            XCTAssertFalse(text.contains("raw server failure"))
        }
    }

    func testLogPurchaseForwardsValidatedAmountAndCurrency() async throws {
        let recorder = PurchaseEventRecorder()
        let fixture = makeFixture(recorder: recorder)
        let commands = try await fixture.handler.handle(.logPurchase(.init(amount: 4.99, currency: "USD")))
        XCTAssertEqual(commands, [])
        let events = await recorder.events
        XCTAssertEqual(events, [.init(amount: 4.99, currency: "USD")])
    }

    func testUnsupportedMessageIsRejected() async {
        let fixture = makeFixture()
        do {
            _ = try await fixture.handler.handle(.logout)
            XCTFail("Expected unsupported message")
        } catch {
            XCTAssertEqual(error as? IAPBridgeError, .unsupported)
        }
    }

    func testConcurrentPurchaseIsRejectedWithoutOpeningSecondStoreSheet() async throws {
        let gate = PurchaseGate()
        let fixture = makeFixture(gate: gate)
        let first = Task { try await fixture.handler.handle(.openAppPurchase(.init(goodsCode: "monthly", paySource: "one", invitationID: ""))) }
        await gate.waitUntilEntered()
        let second = try await fixture.handler.handle(.openAppPurchase(.init(goodsCode: "monthly", paySource: "two", invitationID: "")))
        guard case let .iapLog(value) = second.first,
              let object = value.foundationObject as? [String: Any] else {
            return XCTFail("Expected duplicate rejection log")
        }
        XCTAssertEqual(object["code"] as? String, "purchase_in_progress")
        await gate.release()
        _ = try await first.value
        let purchaseCount = await fixture.store.purchaseCount
        XCTAssertEqual(purchaseCount, 1)
    }

    func testCommandsUseExistingSafeJavaScriptCallbacks() throws {
        let value = JSONValue.object(["text": .string("quote \" slash \\ line\n海")])
        XCTAssertEqual(
            try IAPBridgeCommand.productPrices(value).javaScript(),
            try JavaScriptCallbackEncoder.productPriceResult(value)
        )
        XCTAssertEqual(
            try IAPBridgeCommand.iapLog(value).javaScript(),
            try JavaScriptCallbackEncoder.iapLog(value)
        )
    }
}

private enum BridgePurchaseScenario: CaseIterable {
    case purchased, pending, cancelled, failed
    var status: String {
        switch self { case .purchased: "purchased"; case .pending: "pending"; case .cancelled: "cancelled"; case .failed: "failed" }
    }
}

private struct BridgeFixture {
    let handler: IAPBridgeHandler
    let store: BridgePurchaseStore
}

private func makeFixture(
    products: [StoreProduct] = [],
    scenario: BridgePurchaseScenario = .purchased,
    recorder: PurchaseEventRecorder = PurchaseEventRecorder(),
    gate: PurchaseGate? = nil
) -> BridgeFixture {
    let store = BridgePurchaseStore(products: products, scenario: scenario, gate: gate)
    let coordinator = PurchaseCoordinator(store: store, server: BridgePurchaseServer(scenario: scenario), entitlements: EntitlementStore())
    let handler = IAPBridgeHandler(catalog: ProductCatalog(store: store), coordinator: coordinator) { event in
        await recorder.record(event)
    }
    return .init(handler: handler, store: store)
}

private actor BridgePurchaseStore: PurchaseStoreProviding {
    let availableProducts: [StoreProduct]
    let scenario: BridgePurchaseScenario
    let gate: PurchaseGate?
    private(set) var purchaseCount = 0
    init(products: [StoreProduct], scenario: BridgePurchaseScenario, gate: PurchaseGate?) {
        availableProducts = products; self.scenario = scenario; self.gate = gate
    }
    func products(for ids: [String]) async throws -> [StoreProduct] { availableProducts.filter { ids.contains($0.id) } }
    func purchase(productID: String, orderID: String) async throws -> StorePurchaseResult {
        purchaseCount += 1
        if let gate { await gate.enter() }
        switch scenario {
        case .purchased: return .verified(.init(productID: productID, transactionID: "tx", signedData: "signed-secret", orderID: orderID))
        case .pending: return .pending
        case .cancelled: return .cancelled
        case .failed: throw BridgeTestError.rawServerFailure
        }
    }
    func finish(transactionID: String) async {}
    func restore() async throws -> [StoreTransaction] { [] }
    func transactionUpdates() async -> AsyncStream<StoreTransaction> { AsyncStream { $0.finish() } }
}

private actor BridgePurchaseServer: PurchaseServerProviding {
    let scenario: BridgePurchaseScenario
    init(scenario: BridgePurchaseScenario) { self.scenario = scenario }
    func createOrder(_ request: PurchaseRequest) async throws -> PurchaseOrder {
        if scenario == .failed { throw BridgeTestError.rawServerFailure }
        return .init(orderID: "order", productID: request.productID)
    }
    func verify(orderID: String?, transaction: StoreTransaction) async throws -> EntitlementSnapshot {
        .init(productID: transaction.productID, isActive: true)
    }
}

private actor PurchaseEventRecorder {
    private(set) var events: [PurchaseLogPayload] = []
    func record(_ event: PurchaseLogPayload) { events.append(event) }
}
private enum BridgeTestError: Error { case rawServerFailure }

private actor PurchaseGate {
    private var entered = false
    private var released = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []
    func enter() async {
        entered = true
        entryWaiters.forEach { $0.resume() }; entryWaiters.removeAll()
        if !released { await withCheckedContinuation { releaseWaiters.append($0) } }
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }
    func release() {
        released = true
        releaseWaiters.forEach { $0.resume() }; releaseWaiters.removeAll()
    }
}
