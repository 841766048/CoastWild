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
public struct PendingPurchase: Equatable, Sendable {
    public let productID: String
    public let transactionID: String
}

public actor PurchaseCoordinator {
    private let store: any PurchaseStoreProviding
    private let server: any PurchaseServerProviding
    private let entitlements: EntitlementStore
    private let fulfillment: (any PurchaseTransactionFulfilling)?
    private var pending: [String: StoreTransaction] = [:]
    private var processing: [String: Task<EntitlementSnapshot, Error>] = [:]
    private var purchasingProducts: Set<String> = []
    private var approvalProducts: Set<String> = []
    private var productAliases: [String: String] = [:]
    private var completed: [String: EntitlementSnapshot] = [:]
    private var rejected: Set<String> = []
    public init(store: any PurchaseStoreProviding, server: any PurchaseServerProviding, entitlements: EntitlementStore, fulfillment: (any PurchaseTransactionFulfilling)? = nil) {
        self.store = store; self.server = server; self.entitlements = entitlements
        self.fulfillment = fulfillment
    }
    public func pendingPurchases() -> [PendingPurchase] {
        let transactions = pending.values.map { PendingPurchase(productID: $0.productID, transactionID: $0.transactionID) }
        let approvals = approvalProducts.filter { product in !transactions.contains { $0.productID == product } }
            .map { PendingPurchase(productID: $0, transactionID: "") }
        return (transactions + approvals).sorted { ($0.productID, $0.transactionID) < ($1.productID, $1.transactionID) }
    }
    @discardableResult
    public func synchronizePendingPurchases() async -> [PendingPurchase] {
        for transaction in await store.unfinishedTransactions() {
            let id = transaction.transactionID
            guard completed[id] == nil, !rejected.contains(id), pending[id] == nil else { continue }
            pending[id] = transaction
        }
        return pendingPurchases()
    }
    public func retryPendingPurchases() async throws -> [EntitlementSnapshot] {
        var recovered: [EntitlementSnapshot] = []
        for transaction in Array(pending.values) { recovered.append(try await complete(transaction)) }
        return recovered.sorted { $0.productID < $1.productID }
    }
    public func purchase(_ request: PurchaseRequest) async throws -> PurchaseResult {
        let knownSKU = productAliases[request.productID] ?? request.productID
        guard !purchasingProducts.contains(request.productID), !purchasingProducts.contains(knownSKU),
              !hasUnresolvedPurchase(productID: knownSKU) else { return .pending }
        purchasingProducts.insert(request.productID)
        var claimedSKU: String?
        defer {
            purchasingProducts.remove(request.productID)
            if let claimedSKU { purchasingProducts.remove(claimedSKU) }
        }
        await synchronizePendingPurchases()
        guard !hasUnresolvedPurchase(productID: knownSKU) else { return .pending }
        let order = try await server.createOrder(request)
        productAliases[request.productID] = order.productID
        guard !hasUnresolvedPurchase(productID: order.productID) else { return .pending }
        if order.productID != request.productID {
            guard !purchasingProducts.contains(order.productID) else { return .pending }
            purchasingProducts.insert(order.productID)
            claimedSKU = order.productID
        }
        switch try await store.purchase(productID: order.productID, orderID: order.orderID) {
        case .cancelled: return .cancelled
        case .pending: approvalProducts.insert(order.productID); return .pending
        case .unverified: throw PurchaseError.unverifiedTransaction
        case let .verified(transaction):
            let retained = StoreTransaction(productID: transaction.productID, transactionID: transaction.transactionID,
                                            signedData: transaction.signedData, orderID: transaction.orderID ?? order.orderID)
            let entitlement = try await complete(retained)
            return .purchased(entitlement)
        }
    }
    private func hasUnresolvedPurchase(productID: String) -> Bool {
        approvalProducts.contains(productID) || pending.values.contains { $0.productID == productID }
    }
    public func restorePurchases() async throws -> [EntitlementSnapshot] {
        let transactions = try await store.restore()
        for transaction in transactions where completed[transaction.transactionID] == nil {
            pending[transaction.transactionID] = transaction
        }
        var restored: [EntitlementSnapshot] = []
        for transaction in transactions {
            do { restored.append(try await complete(transaction)) }
            catch PurchaseError.inactiveEntitlement { continue }
        }
        return restored.sorted { $0.productID < $1.productID }
    }
    public func observeTransactionUpdates() async {
        let updates = await store.transactionUpdates()
        for await transaction in updates {
            do {
                _ = try await complete(transaction)
            } catch {
                // Leave the StoreKit transaction unfinished so a later launch can retry verification.
            }
        }
    }
    private func complete(_ transaction: StoreTransaction) async throws -> EntitlementSnapshot {
        let id = transaction.transactionID
        if let snapshot = completed[id] { return snapshot }
        if let task = processing[id] { return try await task.value }
        pending[id] = transaction
        let task = Task { [server, fulfillment, entitlements, store] in
            let snapshot = try await server.verify(orderID: transaction.orderID, transaction: transaction)
            guard snapshot.isActive else { throw PurchaseError.inactiveEntitlement }
            try await fulfillment?.fulfill(transaction)
            await entitlements.update(snapshot)
            await store.finish(transactionID: id)
            return snapshot
        }
        processing[id] = task
        defer { processing[id] = nil }
        let snapshot: EntitlementSnapshot
        do { snapshot = try await task.value }
        catch PurchaseError.inactiveEntitlement {
            rejected.insert(id)
            pending[id] = nil
            approvalProducts.remove(transaction.productID)
            throw PurchaseError.inactiveEntitlement
        }
        pending[id] = nil
        completed[id] = snapshot
        rejected.remove(id)
        approvalProducts.remove(transaction.productID)
        return snapshot
    }
}
