import Foundation
import Security

public enum KeychainAccessibility: Equatable, Sendable {
    case afterFirstUnlockThisDeviceOnly
}

public protocol KeychainValueStoring: Sendable {
    func read(account: String) throws -> String?
    func write(_ value: String, account: String, accessibility: KeychainAccessibility) throws
}

public enum DeviceIdentityError: Error, Equatable, Sendable {
    case keychain(OSStatus)
    case invalidKeychainValue
}

public struct SecurityKeychainValueStore: KeychainValueStoring {
    private let service: String

    public init(service: String = "com.coastwild.integration.device") {
        self.service = service
    }

    public func read(account: String) throws -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ] as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw DeviceIdentityError.keychain(status)
        }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            throw DeviceIdentityError.invalidKeychainValue
        }
        return value
    }

    public func write(
        _ value: String,
        account: String,
        accessibility: KeychainAccessibility
    ) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let data = Data(value.utf8)
        var status = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            item[kSecAttrAccessible] = securityAccessibility(accessibility)
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw DeviceIdentityError.keychain(status)
        }
    }

    private func securityAccessibility(_ value: KeychainAccessibility) -> CFString {
        switch value {
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}

public actor DeviceIdentityStore {
    public static let defaultsKey = "uuidKey"

    private let account: String
    private let defaults: UserDefaults
    private let keychain: any KeychainValueStoring
    private let uuidGenerator: @Sendable () -> UUID

    public init(
        bundleIdentifier: String,
        defaults: UserDefaults = .standard,
        keychain: any KeychainValueStoring = SecurityKeychainValueStore(),
        uuidGenerator: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        account = bundleIdentifier + "_UUID"
        self.defaults = defaults
        self.keychain = keychain
        self.uuidGenerator = uuidGenerator
    }

    public func resolve() throws -> String {
        if let cached = nonempty(defaults.string(forKey: Self.defaultsKey)) {
            return cached
        }
        if let restored = nonempty(try keychain.read(account: account)) {
            defaults.set(restored, forKey: Self.defaultsKey)
            return restored
        }

        let generated = uuidGenerator().uuidString.lowercased()
        try keychain.write(
            generated,
            account: account,
            accessibility: .afterFirstUnlockThisDeviceOnly
        )
        defaults.set(generated, forKey: Self.defaultsKey)
        return generated
    }

    private func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }
}
