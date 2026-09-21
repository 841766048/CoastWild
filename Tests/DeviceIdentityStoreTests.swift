import Foundation
import XCTest
@testable import CoastWildCore

final class DeviceIdentityStoreTests: XCTestCase {
    func testUserDefaultsValueWinsWithoutKeychainAccess() async throws {
        let defaults = makeDefaults()
        defaults.set("cached-device", forKey: "uuidKey")
        let keychain = KeychainFake(value: "keychain-device")
        let store = DeviceIdentityStore(
            bundleIdentifier: "test.duckegg.ios",
            defaults: defaults,
            keychain: keychain,
            uuidGenerator: { UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")! }
        )

        let value = try await store.resolve()

        XCTAssertEqual(value, "cached-device")
        XCTAssertEqual(keychain.readAccounts, [])
        XCTAssertEqual(keychain.writes.count, 0)
    }

    func testKeychainValueRestoresUserDefaults() async throws {
        let defaults = makeDefaults()
        let keychain = KeychainFake(value: "keychain-device")
        let store = DeviceIdentityStore(
            bundleIdentifier: "test.duckegg.ios",
            defaults: defaults,
            keychain: keychain
        )

        let value = try await store.resolve()

        XCTAssertEqual(value, "keychain-device")
        XCTAssertEqual(defaults.string(forKey: "uuidKey"), "keychain-device")
        XCTAssertEqual(keychain.readAccounts, ["test.duckegg.ios_UUID"])
    }

    func testGeneratedUUIDIsWrittenToBothStoresWithRequiredAccessibility() async throws {
        let defaults = makeDefaults()
        let keychain = KeychainFake(value: nil)
        let store = DeviceIdentityStore(
            bundleIdentifier: "test.duckegg.ios",
            defaults: defaults,
            keychain: keychain,
            uuidGenerator: { UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")! }
        )

        let value = try await store.resolve()

        XCTAssertEqual(value, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        XCTAssertEqual(defaults.string(forKey: "uuidKey"), value)
        XCTAssertEqual(
            keychain.writes,
            [.init(account: "test.duckegg.ios_UUID", value: value, accessibility: .afterFirstUnlockThisDeviceOnly)]
        )
    }

    private func makeDefaults() -> UserDefaults {
        let name = "DeviceIdentityStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private final class KeychainFake: KeychainValueStoring, @unchecked Sendable {
    struct Write: Equatable {
        let account: String
        let value: String
        let accessibility: KeychainAccessibility
    }

    private let value: String?
    private(set) var readAccounts: [String] = []
    private(set) var writes: [Write] = []

    init(value: String?) {
        self.value = value
    }

    func read(account: String) throws -> String? {
        readAccounts.append(account)
        return value
    }

    func write(_ value: String, account: String, accessibility: KeychainAccessibility) throws {
        writes.append(.init(account: account, value: value, accessibility: accessibility))
    }
}
