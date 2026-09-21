import Foundation
import StoreKit

actor StoreKit2PurchaseStore: PurchaseStoreProviding {
  private var productsByID: [String: Product] = [:]
  private var transactionsByID: [String: Transaction] = [:]
  private let defaults: UserDefaults
  private let keyPrefix = "com.coastwild.iap.order."

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  func products(for ids: [String]) async throws -> [StoreProduct] {
    let products = try await Product.products(for: ids)
    for product in products { productsByID[product.id] = product }
    return products.map {
      StoreProduct(
        id: $0.id,
        displayName: $0.displayName,
        displayPrice: $0.displayPrice,
        currencyCode: $0.priceFormatStyle.currencyCode,
        subscriptionPeriod: $0.subscription?.subscriptionPeriod.iso8601
      )
    }
  }

  func purchase(productID: String, orderID: String) async throws -> StorePurchaseResult {
    guard AppStore.canMakePayments else { throw StoreKitPurchaseError.paymentsNotAllowed }
    let product: Product
    if let cached = productsByID[productID] { product = cached }
    else {
      guard let fetched = try await Product.products(for: [productID]).first else { throw StoreKitPurchaseError.productNotFound }
      productsByID[productID] = fetched; product = fetched
    }
    defaults.set(orderID, forKey: keyPrefix + "pending." + productID)
    let result = try await product.purchase()
    switch result {
    case .userCancelled:
      defaults.removeObject(forKey: keyPrefix + "pending." + productID); return .cancelled
    case .pending: return .pending
    case let .success(verification):
      guard case let .verified(transaction) = verification else { return .unverified }
      let transactionID = String(transaction.id)
      transactionsByID[transactionID] = transaction
      defaults.set(orderID, forKey: keyPrefix + transactionID)
      defaults.removeObject(forKey: keyPrefix + "pending." + productID)
      return .verified(.init(productID: transaction.productID, transactionID: transactionID, signedData: verification.jwsRepresentation, orderID: orderID))
    @unknown default: return .unverified
    }
  }

  func finish(transactionID: String) async {
    if let transaction = transactionsByID.removeValue(forKey: transactionID) { await transaction.finish() }
    defaults.removeObject(forKey: keyPrefix + transactionID)
  }

  func restore() async throws -> [StoreTransaction] {
    try await AppStore.sync()
    var restored: [StoreTransaction] = []
    for await verification in Transaction.currentEntitlements {
      guard case let .verified(transaction) = verification else { continue }
      let transactionID = String(transaction.id)
      guard let orderID = defaults.string(forKey: keyPrefix + transactionID), !orderID.isEmpty else { continue }
      transactionsByID[transactionID] = transaction
      restored.append(.init(productID: transaction.productID, transactionID: transactionID, signedData: verification.jwsRepresentation, orderID: orderID))
    }
    return restored
  }

  func transactionUpdates() async -> AsyncStream<StoreTransaction> {
    AsyncStream { continuation in
      let task = Task {
        for await verification in Transaction.updates {
          guard case let .verified(transaction) = verification else { continue }
          let transactionID = String(transaction.id)
          guard let orderID = self.defaults.string(forKey: self.keyPrefix + transactionID), !orderID.isEmpty else { continue }
          self.remember(transaction)
          continuation.yield(.init(productID: transaction.productID, transactionID: transactionID, signedData: verification.jwsRepresentation, orderID: orderID))
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private func remember(_ transaction: Transaction) { transactionsByID[String(transaction.id)] = transaction }
}

private enum StoreKitPurchaseError: Error {
  case paymentsNotAllowed
  case productNotFound
}

private extension Product.SubscriptionPeriod {
  var iso8601: String {
    let unit: String
    switch self.unit { case .day: unit = "D"; case .week: unit = "W"; case .month: unit = "M"; case .year: unit = "Y"; @unknown default: unit = "D" }
    return "P\(value)\(unit)"
  }
}
