import Foundation
import StoreKit

actor StoreKit2PurchaseStore: PurchaseStoreProviding {
  private var productsByID: [String: Product] = [:]
  private var transactionsByID: [String: Transaction] = [:]
  private let orderMappings: PurchaseOrderMappingStore

  init(defaults: UserDefaults = .standard) {
    orderMappings = PurchaseOrderMappingStore(defaults: defaults)
  }

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
    guard orderMappings.stage(orderID: orderID, forProductID: productID) else {
      throw StoreKitPurchaseError.pendingPurchaseExists
    }
    let result: Product.PurchaseResult
    do {
      result = try await product.purchase()
    } catch {
      orderMappings.cancelPending(productID: productID)
      throw error
    }
    switch result {
    case .userCancelled:
      orderMappings.cancelPending(productID: productID)
      return .cancelled
    case .pending: return .pending
    case let .success(verification):
      guard case let .verified(transaction) = verification else { return .unverified }
      let transactionID = String(transaction.id)
      transactionsByID[transactionID] = transaction
      orderMappings.associate(orderID: orderID, transactionID: transactionID)
      orderMappings.cancelPending(productID: productID)
      return .verified(.init(productID: transaction.productID, transactionID: transactionID, signedData: verification.jwsRepresentation, orderID: orderID))
    @unknown default: return .unverified
    }
  }

  func finish(transactionID: String) async {
    guard let transaction = transactionsByID.removeValue(forKey: transactionID) else { return }
    await transaction.finish()
    orderMappings.finish(transactionID: transactionID)
  }

  func restore() async throws -> [StoreTransaction] {
    try await AppStore.sync()
    var restored: [StoreTransaction] = []
    for await verification in Transaction.currentEntitlements {
      guard case let .verified(transaction) = verification else { continue }
      let transactionID = String(transaction.id)
      transactionsByID[transactionID] = transaction
      restored.append(orderMappings.restoredTransaction(
        productID: transaction.productID,
        transactionID: transactionID,
        signedData: verification.jwsRepresentation
      ))
    }
    return restored
  }

  func transactionUpdates() async -> AsyncStream<StoreTransaction> {
    AsyncStream { continuation in
      let task = Task {
        for await verification in Transaction.unfinished {
          guard !Task.isCancelled else { break }
          self.yieldMappedTransaction(verification, to: continuation)
        }
        for await verification in Transaction.updates {
          guard !Task.isCancelled else { break }
          self.yieldMappedTransaction(verification, to: continuation)
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private func yieldMappedTransaction(
    _ verification: VerificationResult<Transaction>,
    to continuation: AsyncStream<StoreTransaction>.Continuation
  ) {
    guard case let .verified(transaction) = verification else { return }
    let transactionID = String(transaction.id)
    guard let orderID = orderMappings.resolveForUpdate(
      transactionID: transactionID,
      productID: transaction.productID
    ) else { return }
    transactionsByID[transactionID] = transaction
    continuation.yield(.init(productID: transaction.productID, transactionID: transactionID, signedData: verification.jwsRepresentation, orderID: orderID))
  }
}

private enum StoreKitPurchaseError: Error {
  case paymentsNotAllowed
  case productNotFound
  case pendingPurchaseExists
}

private extension Product.SubscriptionPeriod {
  var iso8601: String {
    let unit: String
    switch self.unit { case .day: unit = "D"; case .week: unit = "W"; case .month: unit = "M"; case .year: unit = "Y"; @unknown default: unit = "D" }
    return "P\(value)\(unit)"
  }
}
