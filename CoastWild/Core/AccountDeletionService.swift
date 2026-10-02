import Foundation

public struct FirebaseAccountState: Codable, Equatable, Sendable {
    public enum Deletion: String, Codable, Sendable { case cloud, identity, local }
    public let uid: String
    public let account: String
    public var deletion: Deletion?
    public init(uid: String, legacyAccount: String?) {
        self.uid = uid
        self.account = legacyAccount.flatMap { $0.isEmpty ? nil : $0 } ?? uid
    }
    public func belongs(to uid: String) -> Bool { self.uid == uid }
}

public enum FirebaseDeletionWorkflow {
    public static func run(
        state initial: FirebaseAccountState,
        save: (FirebaseAccountState?) async throws -> Void,
        cloud: () async throws -> Void,
        identity: () async throws -> Void,
        local: () async throws -> Void
    ) async throws {
        var state = initial
        if state.deletion == nil { state.deletion = .cloud; try await save(state) }
        if state.deletion == .cloud {
            try await cloud()
            state.deletion = .identity; try await save(state)
        }
        if state.deletion == .identity {
            try await identity()
            state.deletion = .local; try await save(state)
        }
        try await local()
        try await save(nil)
    }
}

public enum AccountDeletionError: Error, Equatable, Sendable {
    case alreadyInProgress
}

public actor AccountDeletionService {
    public typealias Step = @Sendable () async throws -> Void

    private let remoteDelete: Step
    private let localDelete: Step
    private let sessionDelete: Step
    public private(set) var isDeleting = false

    public init(
        remoteDelete: @escaping Step,
        localDelete: @escaping Step,
        sessionDelete: @escaping Step
    ) {
        self.remoteDelete = remoteDelete
        self.localDelete = localDelete
        self.sessionDelete = sessionDelete
    }

    public func deleteAccount() async throws {
        guard !isDeleting else { throw AccountDeletionError.alreadyInProgress }
        isDeleting = true
        defer { isDeleting = false }
        try await remoteDelete()
        try await localDelete()
        try await sessionDelete()
    }
}
