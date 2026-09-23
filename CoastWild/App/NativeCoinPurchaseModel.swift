import Foundation

/// Shared by all native coin screens; leaving a screen does not cancel a payment.
@MainActor final class NativeCoinPurchaseModel {
  enum State: Equatable {
    case idle, purchasing, confirming, awaitingApproval, succeeded, cancelled
    case failed(String)
  }
  private unowned let environment: CoastEnvironment
  private(set) var state: State = .idle
  private(set) var product: StoreProduct?
  private(set) var productError: String?
  private(set) var loadingProduct = false
  private var operation: Task<Void, Never>?
  private var baselineEntries: Set<String> = []
  private var pendingTransactionIDs: Set<String> = []
  private var recoveryBaselineEstablished = false
  init(environment: CoastEnvironment) { self.environment = environment }

  func loadProduct() async {
    guard !loadingProduct else { return }
    loadingProduct = true
    defer { loadingProduct = false }
    let recovered = await environment.purchaseCoordinator?.synchronizePendingPurchases()
      .filter { $0.productID == "1coins_19" } ?? []
    if !recovered.isEmpty {
      // Retain identity before another await lets the observer finish the transaction.
      pendingTransactionIDs.formUnion(recovered.map(\.transactionID).filter { !$0.isEmpty })
      state = recovered.contains { !$0.transactionID.isEmpty } ? .confirming : .awaitingApproval
    }
    do {
      guard let catalog = environment.coinProductCatalog else { throw IAPBridgeError.unsupported }
      let result = try await catalog.load(productIDs: ["1coins_19"])
      guard let fetched = result.products.first(where: { $0.id == "1coins_19" }),
            fetched.subscriptionPeriod == nil else { throw IAPBridgeError.unsupported }
      product = fetched; productError = nil
    } catch {
      product = nil
      productError = "Couldn’t load the App Store price. Check your connection and try again."
    }
    await refreshPending()
  }

  func purchase() {
    guard product != nil, operation == nil, state != .confirming,
          state != .awaitingApproval, state != .purchasing else { return }
    state = .purchasing
    pendingTransactionIDs.removeAll()
    operation = Task {
      defer { operation = nil }
      do {
        baselineEntries = Set(try await environment.coinWallet.snapshot().entries.map(\.id))
        recoveryBaselineEstablished = true
        guard let coordinator = environment.purchaseCoordinator else { throw IAPBridgeError.unsupported }
        switch try await coordinator.purchase(.init(productID: "1coins_19", paySource: "native_learning", invitationID: "")) {
        case .purchased:
          let snapshot = try await environment.coinWallet.snapshot()
          guard snapshot.entries.contains(where: { $0.amount > 0 && !baselineEntries.contains($0.id) }) else {
            state = .failed("No new coins were added. Check My coins before making another purchase.")
            return
          }
          state = .succeeded
        case .pending:
          state = .awaitingApproval
          await refreshPending()
        case .cancelled: state = .cancelled
        }
      } catch {
        await refreshPending()
        if state != .confirming && state != .awaitingApproval {
          state = .failed("The purchase could not be completed. No coins were added. Please try again.")
        }
      }
    }
  }

  func refreshPending() async {
    guard let coordinator = environment.purchaseCoordinator else { return }
    let pending = await coordinator.pendingPurchases().filter { $0.productID == "1coins_19" }
    if !pending.isEmpty {
      pendingTransactionIDs.formUnion(pending.map(\.transactionID).filter { !$0.isEmpty })
      if !recoveryBaselineEstablished {
        do {
          baselineEntries = Set(try await environment.coinWallet.snapshot().entries.map(\.id))
          recoveryBaselineEstablished = true
        } catch { state = .failed("Your local wallet could not be read. Keep this app installed and contact support."); return }
      }
      state = pending.contains { !$0.transactionID.isEmpty } ? .confirming : .awaitingApproval
    } else if state == .confirming || state == .awaitingApproval {
      do {
        let snapshot = try await environment.coinWallet.snapshot()
        let fulfilled = snapshot.entries.contains { entry in
          guard entry.amount > 0 else { return false }
          if !pendingTransactionIDs.isEmpty {
            return pendingTransactionIDs.contains { entry.id == "transaction:\($0)" }
          }
          return !baselineEntries.contains(entry.id)
        }
        if fulfilled {
          state = .succeeded
        } else {
          state = .failed("The purchase could not be verified. No coins were added. Please try again or contact support.")
        }
      } catch { /* Keep pending; never encourage another purchase on storage failure. */ }
    }
  }

  func retryVerification() {
    guard operation == nil, state == .confirming else { return }
    operation = Task {
      defer { operation = nil }
      do {
        _ = try await environment.purchaseCoordinator?.retryPendingPurchases()
        await refreshPending()
      } catch {
        // An inactive entitlement clears the coordinator's pending transaction.
        // Transient failures remain pending; terminal rejection must leave this screen.
        await refreshPending()
      }
    }
  }
  func acknowledge() {
    guard operation == nil else { return }
    if state == .succeeded || state == .cancelled {
      state = .idle; recoveryBaselineEstablished = false
      pendingTransactionIDs.removeAll()
    }
  }
}

#if DEBUG
/// Deterministic test doubles are compiled out of release and require both UI-test flags.
actor NativeCoinTestStore: PurchaseStoreProviding {
  private static let recoveryTransactionID = "ui-test-credited-unfinished"
  func products(for ids: [String]) async throws -> [StoreProduct] {
    if ProcessInfo.processInfo.arguments.contains("--coins-price-fails") { throw IAPBridgeError.unsupported }
    return [.init(id: "1coins_19", displayName: "100 Coins", displayPrice: "$0.99",
                  currencyCode: "USD", subscriptionPeriod: nil)]
  }
  func purchase(productID: String, orderID: String) async throws -> StorePurchaseResult {
    try await Task.sleep(nanoseconds: 300_000_000)
    if ProcessInfo.processInfo.arguments.contains("--coins-cancel") { return .cancelled }
    if ProcessInfo.processInfo.arguments.contains("--coins-pending") { return .pending }
    let transactionID = ProcessInfo.processInfo.arguments.contains("--coins-credited-unfinished-seed")
      ? Self.recoveryTransactionID : UUID().uuidString
    return .verified(.init(productID: productID, transactionID: transactionID,
                           signedData: "UI-TEST-ONLY", orderID: orderID))
  }
  func finish(transactionID: String) async {
    if ProcessInfo.processInfo.arguments.contains("--coins-credited-unfinished-seed") {
      // The test terminates the app after wallet persistence and before StoreKit finish.
      try? await Task.sleep(nanoseconds: 120_000_000_000)
    }
  }
  func unfinishedTransactions() async -> [StoreTransaction] {
    guard ProcessInfo.processInfo.arguments.contains("--coins-credited-unfinished-recover") else { return [] }
    return [.init(productID: "1coins_19", transactionID: Self.recoveryTransactionID,
                  signedData: "UI-TEST-ONLY")]
  }
  func restore() async throws -> [StoreTransaction] { [] }
  func transactionUpdates() async -> AsyncStream<StoreTransaction> { AsyncStream { $0.finish() } }
}
actor NativeCoinTestServer: PurchaseServerProviding {
  private var attempts = 0
  func createOrder(_ request: PurchaseRequest) async throws -> PurchaseOrder {
    .init(orderID: UUID().uuidString, productID: request.productID)
  }
  func verify(orderID: String?, transaction: StoreTransaction) async throws -> EntitlementSnapshot {
    attempts += 1
    let rejectsOnRetry = ProcessInfo.processInfo.arguments.contains("--coins-inactive-retry")
    if (ProcessInfo.processInfo.arguments.contains("--coins-verify-retry") || rejectsOnRetry), attempts == 1 {
      throw IAPBridgeError.unsupported
    }
    if rejectsOnRetry, attempts == 2 { return .init(productID: transaction.productID, isActive: false) }
    return .init(productID: transaction.productID, isActive: true)
  }
}
#endif
