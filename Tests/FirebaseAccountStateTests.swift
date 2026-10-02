import XCTest
@testable import CoastWildCore

final class FirebaseAccountStateTests: XCTestCase {
    func testLegacyPartitionIsBoundToExistingFirebaseIdentityOnly() throws {
        let state = FirebaseAccountState(uid: "owner", legacyAccount: "old-account")
        XCTAssertEqual(state.account, "old-account")
        XCTAssertTrue(state.belongs(to: "owner"))
        XCTAssertFalse(state.belongs(to: "other"))
        XCTAssertEqual(FirebaseAccountState(uid: "new", legacyAccount: nil).account, "new")
    }

    func testDeletionProgressSurvivesSerialization() throws {
        var state = FirebaseAccountState(uid: "owner", legacyAccount: nil)
        state.deletion = .identity
        let restored = try JSONDecoder().decode(FirebaseAccountState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.deletion, .identity)
        XCTAssertEqual(restored.uid, "owner")
    }

    func testIdentityFailureKeepsLocalDataAndResumesAtIdentity() async throws {
        let recorder = DeletionRecorder()
        let state = FirebaseAccountState(uid: "owner", legacyAccount: nil)
        do {
            try await FirebaseDeletionWorkflow.run(state: state,
                save: { await recorder.save($0) },
                cloud: { await recorder.record("cloud") },
                identity: { throw DeletionFailure.offline },
                local: { await recorder.record("local") })
            XCTFail("Expected identity deletion failure")
        } catch { XCTAssertTrue(error is DeletionFailure) }
        let pending = await recorder.state
        XCTAssertEqual(pending?.deletion, .identity)
        let first = await recorder.events
        XCTAssertEqual(first, ["cloud"])
        try await FirebaseDeletionWorkflow.run(state: XCTUnwrap(pending),
            save: { await recorder.save($0) },
            cloud: { XCTFail("Cloud deletion must not repeat") },
            identity: { await recorder.record("identity") },
            local: { await recorder.record("local") })
        let completed = await recorder.state
        let events = await recorder.events
        XCTAssertNil(completed)
        XCTAssertEqual(events, ["cloud", "identity", "local"])
    }

    func testCloudFailureDoesNotDeleteIdentityOrLocalData() async throws {
        let recorder = DeletionRecorder()
        do {
            try await FirebaseDeletionWorkflow.run(state: FirebaseAccountState(uid: "owner", legacyAccount: nil),
                save: { await recorder.save($0) },
                cloud: { throw DeletionFailure.offline },
                identity: { XCTFail("Identity must remain") },
                local: { XCTFail("Local data must remain") })
            XCTFail("Expected failure")
        } catch { XCTAssertTrue(error is DeletionFailure) }
        let pending = await recorder.state
        XCTAssertEqual(pending?.deletion, .cloud)
    }

    func testLocalCleanupRetryDoesNotCreateOrDeleteAnotherIdentity() async throws {
        var state = FirebaseAccountState(uid: "deleted-owner", legacyAccount: "old-partition")
        state.deletion = .local
        let recorder = DeletionRecorder()
        try await FirebaseDeletionWorkflow.run(state: state,
            save: { await recorder.save($0) },
            cloud: { XCTFail("Cloud is already deleted") },
            identity: { XCTFail("Identity is already deleted") },
            local: { await recorder.record("local") })
        let events = await recorder.events
        XCTAssertEqual(events, ["local"])
    }
}

private enum DeletionFailure: Error { case offline }
private actor DeletionRecorder {
    var state: FirebaseAccountState?
    var events: [String] = []
    func save(_ value: FirebaseAccountState?) { state = value }
    func record(_ event: String) { events.append(event) }
}
