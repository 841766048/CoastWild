import Foundation

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
