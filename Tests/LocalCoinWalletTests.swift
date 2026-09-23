import XCTest
@testable import CoastWildCore

final class LocalCoinWalletTests: XCTestCase {
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("wallet.json") }
    private func transaction(_ id: String = "tx", product: String = "1coins_19") -> StoreTransaction {
        .init(productID: product, transactionID: id, signedData: "verified")
    }
    func testNewWalletStartsEmpty() async throws {
        let value = try await LocalCoinWallet(fileURL: location()).snapshot()
        XCTAssertEqual(value.balance, 0); XCTAssertTrue(value.entries.isEmpty); XCTAssertTrue(value.unlockedGuideIDs.isEmpty)
    }
    func testDurableDedupeAndUnlock() async throws {
        let url = location(), tx = transaction()
        let wallet = LocalCoinWallet(fileURL: url)
        try await wallet.fulfill(tx); try await wallet.fulfill(tx)
        let reopened = LocalCoinWallet(fileURL: url)
        let credited = try await reopened.snapshot()
        XCTAssertEqual(credited.balance, 100); XCTAssertEqual(credited.entries.count, 1)
        try await reopened.unlock(guideID: "coastal-camping")
        try await reopened.unlock(guideID: "coastal-camping")
        let unlocked = try await LocalCoinWallet(fileURL: url).snapshot()
        XCTAssertEqual(unlocked.balance, 70); XCTAssertEqual(unlocked.unlockedGuideIDs, ["coastal-camping"])
        XCTAssertEqual(unlocked.entries.map(\.amount).sorted(), [-30, 100])
    }
    func testUnknownProductIgnoredAndInvalidUnlocksDoNotMutate() async throws {
        let wallet = LocalCoinWallet(fileURL: location())
        try await wallet.fulfill(transaction(product: "monthly"))
        let before = try await wallet.snapshot()
        for guide in ["coastal-camping", "unknown"] {
            do { try await wallet.unlock(guideID: guide); XCTFail("expected rejection") } catch {}
        }
        let after = try await wallet.snapshot()
        XCTAssertEqual(before, after)
    }
    func testWriteFailureLeavesMemoryUnchanged() async throws {
        let url = location()
        let blocked = LocalCoinWallet(fileURL: url)
        _ = try await blocked.snapshot()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        do { try await blocked.fulfill(transaction()); XCTFail("expected write failure") } catch {}
        try FileManager.default.removeItem(at: url)
        let value = try await blocked.snapshot()
        XCTAssertEqual(value.balance, 0)
    }
    func testCorruptionNeverResetsOrOverwrites() async throws {
        let url = location(), bad = Data("corrupt".utf8)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bad.write(to: url)
        let wallet = LocalCoinWallet(fileURL: url)
        do { _ = try await wallet.snapshot(); XCTFail("expected corruption") } catch {}
        do { try await wallet.fulfill(transaction()); XCTFail("expected corruption") } catch {}
        XCTAssertEqual(try Data(contentsOf: url), bad)
    }
    func testConcurrentDuplicatesCreditOnce() async throws {
        let wallet = LocalCoinWallet(fileURL: location()), tx = transaction()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<30 { group.addTask { try await wallet.fulfill(tx) } }
            try await group.waitForAll()
        }
        let snapshot = try await wallet.snapshot()
        XCTAssertEqual(snapshot.balance, 100); XCTAssertEqual(snapshot.entries.count, 1)
    }
    func testStructurallyValidButInconsistentStorageFailsClosed() async throws {
        let url = location()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bad = Data(#"{"version":1,"balance":100,"unlockedGuideIDs":[],"transactionIDs":[],"entries":[]}"#.utf8)
        try bad.write(to: url)
        let wallet = LocalCoinWallet(fileURL: url)
        do { _ = try await wallet.snapshot(); XCTFail("expected invalid ledger") } catch {}
        do { try await wallet.fulfill(transaction()); XCTFail("expected invalid ledger") } catch {}
        XCTAssertEqual(try Data(contentsOf: url), bad)
    }
}
