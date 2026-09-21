import XCTest
@testable import CoastWildCore

final class AccountDeletionTests: XCTestCase {
    func testRemoteFailureLeavesLocalDataAndSessionUntouched() async {
        let events = EventRecorder()
        let service = AccountDeletionService(
            remoteDelete: { throw StubError.remote },
            localDelete: { await events.append("local") },
            sessionDelete: { await events.append("session") }
        )

        do {
            try await service.deleteAccount()
            XCTFail("expected remote failure")
        } catch {
            XCTAssertEqual(error as? StubError, .remote)
        }
        let recorded = await events.values()
        let deleting = await service.isDeleting
        XCTAssertEqual(recorded, [])
        XCTAssertFalse(deleting)
    }

    func testSuccessDeletesRemoteThenLocalThenSession() async throws {
        let events = EventRecorder()
        let service = AccountDeletionService(
            remoteDelete: { await events.append("remote") },
            localDelete: { await events.append("local") },
            sessionDelete: { await events.append("session") }
        )

        try await service.deleteAccount()

        let recorded = await events.values()
        let deleting = await service.isDeleting
        XCTAssertEqual(recorded, ["remote", "local", "session"])
        XCTAssertFalse(deleting)
    }

    func testLocalFailureDoesNotClearSession() async {
        let events = EventRecorder()
        let service = AccountDeletionService(
            remoteDelete: { await events.append("remote") },
            localDelete: {
                await events.append("local")
                throw StubError.local
            },
            sessionDelete: { await events.append("session") }
        )

        do {
            try await service.deleteAccount()
            XCTFail("expected local failure")
        } catch {
            XCTAssertEqual(error as? StubError, .local)
        }
        let recorded = await events.values()
        XCTAssertEqual(recorded, ["remote", "local"])
    }

    func testConcurrentDeletionIsRejected() async throws {
        let gate = AsyncGate()
        let service = AccountDeletionService(
            remoteDelete: { await gate.wait() },
            localDelete: {},
            sessionDelete: {}
        )
        let first = Task { try await service.deleteAccount() }
        await Task.yield()

        do {
            try await service.deleteAccount()
            XCTFail("expected duplicate rejection")
        } catch {
            XCTAssertEqual(error as? AccountDeletionError, .alreadyInProgress)
        }
        await gate.open()
        try await first.value
    }
}

private enum StubError: Error, Equatable {
    case remote
    case local
}

private actor EventRecorder {
    private var events: [String] = []
    func append(_ event: String) { events.append(event) }
    func values() -> [String] { events }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var opened = false

    func wait() async {
        if opened { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        opened = true
        continuation?.resume()
        continuation = nil
    }
}
