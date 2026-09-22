import Foundation

public struct PurchaseRequest: Equatable, Sendable {
    public let productID: String; public let paySource: String; public let invitationID: String
    public init(productID: String, paySource: String, invitationID: String) {
        self.productID = productID; self.paySource = paySource; self.invitationID = invitationID
    }
}
public struct StoreTransaction: Equatable, Sendable {
    public let productID: String; public let transactionID: String; public let signedData: String; public let orderID: String?
    public init(productID: String, transactionID: String, signedData: String, orderID: String? = nil) {
        self.productID = productID; self.transactionID = transactionID; self.signedData = signedData; self.orderID = orderID
    }
}
public struct PurchaseOrder: Equatable, Sendable {
    public let orderID: String; public let productID: String
    public init(orderID: String, productID: String) { self.orderID = orderID; self.productID = productID }
}
public struct EntitlementSnapshot: Equatable, Sendable {
    public let productID: String; public let isActive: Bool
    public init(productID: String = "", isActive: Bool = false) { self.productID = productID; self.isActive = isActive }
}
public actor EntitlementStore {
    private var current = EntitlementSnapshot()
    public init() {}
    public func update(_ snapshot: EntitlementSnapshot) { current = snapshot }
    public func snapshot() -> EntitlementSnapshot { current }
}
public protocol PurchaseServerProviding: Sendable {
    func createOrder(_ request: PurchaseRequest) async throws -> PurchaseOrder
    func verify(orderID: String?, transaction: StoreTransaction) async throws -> EntitlementSnapshot
}
public enum PurchaseResult: Equatable, Sendable { case purchased(EntitlementSnapshot), pending, cancelled }
public enum PurchaseError: Error, Equatable, Sendable {
  case inactiveEntitlement
  case unverifiedTransaction
}

public actor PurchaseCoordinator {
    private let store: any PurchaseStoreProviding
    private let server: any PurchaseServerProviding
    private let entitlements: EntitlementStore
    public init(store: any PurchaseStoreProviding, server: any PurchaseServerProviding, entitlements: EntitlementStore) {
        self.store = store; self.server = server; self.entitlements = entitlements
    }
    public func purchase(_ request: PurchaseRequest) async throws -> PurchaseResult {
        let order = try await server.createOrder(request)
        switch try await store.purchase(productID: order.productID, orderID: order.orderID) {
        case .cancelled: return .cancelled
        case .pending: return .pending
        case .unverified: throw PurchaseError.unverifiedTransaction
        case let .verified(transaction):
            let entitlement = try await server.verify(orderID: transaction.orderID ?? order.orderID, transaction: transaction)
            guard entitlement.isActive else { throw PurchaseError.inactiveEntitlement }
            await entitlements.update(entitlement)
            await store.finish(transactionID: transaction.transactionID)
            return .purchased(entitlement)
        }
    }
    public func restorePurchases() async throws -> [EntitlementSnapshot] {
        let transactions = try await store.restore()
        return try await withThrowingTaskGroup(of: (EntitlementSnapshot, String).self) { group in
            for transaction in transactions {
                group.addTask { [server] in
                    (try await server.verify(orderID: transaction.orderID, transaction: transaction), transaction.transactionID)
                }
            }
            var restored: [EntitlementSnapshot] = []
            for try await (snapshot, transactionID) in group {
                if snapshot.isActive {
                    await entitlements.update(snapshot)
                    await store.finish(transactionID: transactionID)
                    restored.append(snapshot)
                }
            }
            return restored.sorted { $0.productID < $1.productID }
        }
    }
    public func observeTransactionUpdates() async {
        let updates = await store.transactionUpdates()
        for await transaction in updates {
            do {
                let snapshot = try await server.verify(orderID: transaction.orderID, transaction: transaction)
                guard snapshot.isActive else { continue }
                await entitlements.update(snapshot)
                await store.finish(transactionID: transaction.transactionID)
            } catch {
                // Leave the StoreKit transaction unfinished so a later launch can retry verification.
            }
        }
    }
}
