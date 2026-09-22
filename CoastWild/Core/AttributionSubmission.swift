import Foundation

public struct AttributionSnapshot: Codable, Equatable, Sendable {
    public let source: String
    public let adGroupID: String
    public let adSetID: String
    public let campaignID: String
    public let sdkVersion: String

    public init(source: String, adGroupID: String, adSetID: String, campaignID: String, sdkVersion: String) {
        self.source = Self.sanitize(source)
        self.adGroupID = Self.sanitize(adGroupID)
        self.adSetID = Self.sanitize(adSetID)
        self.campaignID = Self.sanitize(campaignID)
        self.sdkVersion = Self.sanitize(sdkVersion)
    }

    public static func empty(sdkVersion: String) -> Self {
        .init(source: "", adGroupID: "", adSetID: "", campaignID: "", sdkVersion: sdkVersion)
    }

    private static func sanitize(_ value: String) -> String {
        let scalars = value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines).prefix(256).description
    }
}

public protocol AttributionSnapshotProviding: Sendable {
    func nextAttribution() async -> AttributionSnapshot?
}

public protocol AttributionReporting: Sendable {
    func submit(_ snapshot: AttributionSnapshot, userID: String) async throws
}

public final class AttributionSnapshotStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let snapshotKey: String
    private let submittedUsersKey: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "com.coastwild.attribution") {
        self.defaults = defaults
        snapshotKey = keyPrefix + ".snapshot"
        submittedUsersKey = keyPrefix + ".submitted-users"
    }

    public func snapshot() -> AttributionSnapshot? {
        lock.withLock {
            guard let data = defaults.data(forKey: snapshotKey) else { return nil }
            return try? JSONDecoder().decode(AttributionSnapshot.self, from: data)
        }
    }

    public func save(_ snapshot: AttributionSnapshot) {
        lock.withLock {
            if let data = try? JSONEncoder().encode(snapshot) {
                defaults.set(data, forKey: snapshotKey)
            }
        }
    }

    public func isSubmitted(userID: String) -> Bool {
        lock.withLock { Set(defaults.stringArray(forKey: submittedUsersKey) ?? []).contains(userID) }
    }

    public func markSubmitted(userID: String) {
        lock.withLock {
            var users = Set(defaults.stringArray(forKey: submittedUsersKey) ?? [])
            users.insert(userID)
            defaults.set(Array(users).sorted(), forKey: submittedUsersKey)
        }
    }
}

public actor AttributionSubmissionCoordinator {
    public typealias Fallback = @Sendable () async -> Void
    private let provider: any AttributionSnapshotProviding
    private let store: AttributionSnapshotStore
    private let reporter: any AttributionReporting
    private let fallback: Fallback
    private let sdkVersion: String
    private var inFlightUsers: Set<String> = []

    public init(provider: any AttributionSnapshotProviding, store: AttributionSnapshotStore,
                reporter: any AttributionReporting, sdkVersion: String = "5.8.0",
                fallback: @escaping Fallback = { try? await Task.sleep(nanoseconds: 30_000_000_000) }) {
        self.provider = provider; self.store = store; self.reporter = reporter
        self.sdkVersion = sdkVersion; self.fallback = fallback
    }

    public func submitOnce(userID: String) async throws {
        let userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userID.isEmpty, !store.isSubmitted(userID: userID), !inFlightUsers.contains(userID) else { return }
        inFlightUsers.insert(userID)
        defer { inFlightUsers.remove(userID) }

        let snapshot: AttributionSnapshot
        if let stored = store.snapshot() {
            snapshot = stored
        } else {
            snapshot = await firstSnapshotOrFallback() ?? .empty(sdkVersion: sdkVersion)
            store.save(snapshot)
        }
        try await reporter.submit(snapshot, userID: userID)
        store.markSubmitted(userID: userID)
    }

    private func firstSnapshotOrFallback() async -> AttributionSnapshot? {
        await withTaskGroup(of: AttributionSnapshot?.self) { group in
            group.addTask { await self.provider.nextAttribution() }
            group.addTask { await self.fallback(); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock(); defer { unlock() }; return operation()
    }
}
