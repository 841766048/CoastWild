import CommonCrypto
import Foundation
import Security

struct CoastAccount: Codable {
  var id: String
  var name: String
  var email: String
  var salt: Data
  var digest: Data
}
final class AccountVault {
  private struct VaultData: Codable {
    var accounts: [CoastAccount] = []
    var session: String?
  }
  private var data: VaultData
  private let storage: any AccountDataStore
  private var recovery: (email: String, code: String, expires: Date, attempts: Int)?
  var current: CoastAccount? { data.accounts.first { $0.id == data.session } }
  init(testing: Bool) throws {
    let namespace = testing ? "test" : "accounts"
    let destination = UserDefaultsAccountDataStore(
      defaults: .standard,
      key: "com.coastwild.native.\(namespace).vault")
    let legacy = KeychainAccountDataStore(service: "com.coastwild.native.\(namespace)")
    storage = MigratingAccountDataStore(destination: destination, legacy: legacy)
    if let bytes = try storage.load() {
      do {
        data = try JSONDecoder().decode(VaultData.self, from: bytes)
      } catch {
        throw VaultError.storage
      }
    } else {
      data = VaultData()
    }
  }
  private func persist(_ next: VaultData) throws {
    let bytes = try JSONEncoder().encode(next)
    try storage.save(bytes)
    data = next
  }
  private func derive(_ password: String, salt: Data) throws -> Data {
    var digest = [UInt8](repeating: 0, count: 32)
    let bytes = Array(password.utf8)
    let status = bytes.withUnsafeBytes { p in
      salt.withUnsafeBytes { s in
        CCKeyDerivationPBKDF(
          CCPBKDFAlgorithm(kCCPBKDF2), p.baseAddress!.assumingMemoryBound(to: Int8.self),
          bytes.count, s.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
          CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 120_000, &digest, 32)
      }
    }
    guard status == kCCSuccess else { throw VaultError.storage }
    return Data(digest)
  }
  func register(name: String, email: String, password: String) throws {
    let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard CoastValidation.email(email), CoastValidation.password(password),
      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 60
    else { throw VaultError.invalid }
    guard !data.accounts.contains(where: { $0.email == email }) else { throw VaultError.duplicate }
    var salt = [UInt8](repeating: 0, count: 16)
    guard SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt) == errSecSuccess else {
      throw VaultError.storage
    }
    let account = CoastAccount(
      id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      email: email, salt: Data(salt), digest: try derive(password, salt: Data(salt)))
    var next = data
    next.accounts.append(account)
    next.session = account.id
    try persist(next)
  }
  func login(email: String, password: String) throws {
    guard !password.isEmpty,
      let account = data.accounts.first(where: {
        $0.email == email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      })
    else { throw VaultError.credentials }
    let candidate = try derive(password, salt: account.salt)
    let diff = zip(candidate, account.digest).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) }
    guard diff == 0 else { throw VaultError.credentials }
    var next = data
    next.session = account.id
    try persist(next)
  }
  func logout() throws {
    var next = data
    next.session = nil
    try persist(next)
  }
  func requestRecovery(email: String) throws -> String {
    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard data.accounts.contains(where: { $0.email == normalized }) else {
      throw VaultError.credentials
    }
    let code = String(format: "%06d", Int.random(in: 0...999999))
    recovery = (normalized, code, Date().addingTimeInterval(600), 0)
    return code
  }
  func reset(code: String, password: String) throws {
    guard var request = recovery, request.expires > Date(), request.attempts < 5 else {
      throw VaultError.expired
    }
    request.attempts += 1
    recovery = request
    guard code == request.code else { throw VaultError.code }
    guard CoastValidation.password(password),
      let i = data.accounts.firstIndex(where: { $0.email == request.email })
    else { throw VaultError.invalid }
    var next = data
    next.accounts[i].digest = try derive(password, salt: next.accounts[i].salt)
    next.session = nil
    try persist(next)
    recovery = nil
  }
  func clearTestVault() throws { try persist(VaultData()) }
}

private struct KeychainAccountDataStore: AccountDataStore {
  let service: String
  private let account = "vault"

  func load() throws -> Data? {
    var result: CFTypeRef?
    let status = SecItemCopyMatching(
      [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecReturnData: true,
        kSecMatchLimit: kSecMatchLimitOne,
      ] as CFDictionary,
      &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let bytes = result as? Data else {
      throw VaultError.storage
    }
    return bytes
  }

  func save(_ data: Data) throws {
    let query = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: service,
      kSecAttrAccount: account,
    ] as CFDictionary
    var status = SecItemUpdate(query, [kSecValueData: data] as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(
        [
          kSecClass: kSecClassGenericPassword,
          kSecAttrService: service,
          kSecAttrAccount: account,
          kSecValueData: data,
          kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ] as CFDictionary,
        nil)
    }
    guard status == errSecSuccess else { throw VaultError.storage }
  }

  func remove() throws {
    let status = SecItemDelete(
      [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
      ] as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw VaultError.storage
    }
  }
}

enum VaultError: String, LocalizedError {
  case storage, invalid, duplicate, credentials, expired, code
  var errorDescription: String? { "auth.\(rawValue)" }
}
