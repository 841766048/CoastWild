import Foundation

public struct StoreProduct: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let currencyCode: String
    public let subscriptionPeriod: String?
    public init(id: String, displayName: String, displayPrice: String, currencyCode: String, subscriptionPeriod: String?) {
        self.id = id; self.displayName = displayName; self.displayPrice = displayPrice
        self.currencyCode = currencyCode; self.subscriptionPeriod = subscriptionPeriod
    }
}

public struct ProductCatalogResult: Equatable, Sendable {
    public let products: [StoreProduct]
    public let missingProductIDs: [String]
    public var bridgeValue: JSONValue {
        .object(["data": .array(products.map {
            .object(["id": .string($0.id), "localPrice": .string($0.displayPrice), "currencyCode": .string($0.currencyCode)])
        })])
    }
}

public enum StorePurchaseResult: Equatable, Sendable {
    case verified(StoreTransaction)
    case unverified
    case pending
    case cancelled
}

public protocol PurchaseStoreProviding: Sendable {
    func products(for ids: [String]) async throws -> [StoreProduct]
    func purchase(productID: String, orderID: String) async throws -> StorePurchaseResult
    func finish(transactionID: String) async
    func restore() async throws -> [StoreTransaction]
    func transactionUpdates() async -> AsyncStream<StoreTransaction>
    func unfinishedTransactions() async -> [StoreTransaction]
}
public extension PurchaseStoreProviding {
    func unfinishedTransactions() async -> [StoreTransaction] { [] }
}

public struct ProductCatalog: Sendable {
    private let store: any PurchaseStoreProviding
    public init(store: any PurchaseStoreProviding) { self.store = store }
    public func load(productIDs: [String]) async throws -> ProductCatalogResult {
        let unique = productIDs.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let fetched = try await store.products(for: unique)
        let indexed = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        return ProductCatalogResult(
            products: unique.compactMap { indexed[$0] },
            missingProductIDs: unique.filter { indexed[$0] == nil }
        )
    }
}
