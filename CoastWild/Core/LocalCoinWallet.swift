import Foundation

public struct CoinWalletEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let amount: Int
    public let date: Date
}
public struct CoinWalletSnapshot: Codable, Equatable, Sendable {
    public let balance: Int
    public let unlockedGuideIDs: Set<String>
    public let entries: [CoinWalletEntry]
}
public protocol PurchaseTransactionFulfilling: Sendable {
    func fulfill(_ transaction: StoreTransaction) async throws
}
public enum CoinWalletError: Error, Equatable, Sendable {
    case unknownGuide, insufficientBalance, invalidStorage
}
public actor LocalCoinWallet: PurchaseTransactionFulfilling {
    private struct State: Codable {
        var version = 1
        var balance = 0
        var unlockedGuideIDs: Set<String> = []
        var transactionIDs: Set<String> = []
        var entries: [CoinWalletEntry] = []
    }
    private let fileURL: URL
    private let writer: @Sendable (Data, URL) throws -> Void
    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.writer = { data, url in try data.write(to: url, options: .atomic) }
    }
    init(fileURL: URL, writer: @escaping @Sendable (Data, URL) throws -> Void) {
        self.fileURL = fileURL; self.writer = writer
    }
    public func snapshot() throws -> CoinWalletSnapshot {
        let state = try load()
        return .init(balance: state.balance, unlockedGuideIDs: state.unlockedGuideIDs, entries: state.entries)
    }
    public func unlock(guideID: String) throws {
        guard guideID == "coastal-camping" else { throw CoinWalletError.unknownGuide }
        var next = try load()
        guard !next.unlockedGuideIDs.contains(guideID) else { return }
        guard next.balance >= 30 else { throw CoinWalletError.insufficientBalance }
        next.balance -= 30
        next.unlockedGuideIDs.insert(guideID)
        next.entries.insert(.init(id: "guide:\(guideID)", title: "Coastal Camping", amount: -30, date: Date()), at: 0)
        try persist(next)
    }
    public func fulfill(_ transaction: StoreTransaction) async throws {
        // Other bridge products remain handled by their existing entitlement flow.
        guard transaction.productID == "1coins_19" else { return }
        var next = try load()
        guard !next.transactionIDs.contains(transaction.transactionID) else { return }
        guard !transaction.transactionID.isEmpty, next.balance <= Int.max - 100 else { throw CoinWalletError.invalidStorage }
        next.balance += 100
        next.transactionIDs.insert(transaction.transactionID)
        next.entries.insert(.init(id: "transaction:\(transaction.transactionID)", title: "100 Coins", amount: 100, date: Date()), at: 0)
        try persist(next)
    }
    private func load() throws -> State {
        let data: Data
        do { data = try Data(contentsOf: fileURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return State() }
        let state = try JSONDecoder().decode(State.self, from: data)
        guard state.version == 1, state.balance >= 0,
              state.unlockedGuideIDs.isSubset(of: ["coastal-camping"]),
              Set(state.entries.map(\.id)).count == state.entries.count,
              state.entries.count == state.transactionIDs.count + state.unlockedGuideIDs.count,
              state.transactionIDs.allSatisfy({ id in !id.isEmpty && state.entries.contains { $0.id == "transaction:\(id)" && $0.amount == 100 } }),
              state.unlockedGuideIDs.allSatisfy({ id in state.entries.contains { $0.id == "guide:\(id)" && $0.amount == -30 } })
        else { throw CoinWalletError.invalidStorage }
        var total = 0
        for entry in state.entries {
            let (sum, overflow) = total.addingReportingOverflow(entry.amount)
            guard !overflow else { throw CoinWalletError.invalidStorage }
            total = sum
        }
        guard total == state.balance else { throw CoinWalletError.invalidStorage }
        return state
    }
    private func persist(_ state: State) throws {
        let data = try JSONEncoder().encode(state)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writer(data, fileURL)
    }
}
