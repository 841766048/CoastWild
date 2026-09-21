import Foundation

public enum IntegrationKeyDeriver {
    public enum DerivationError: Error, Equatable, Sendable {
        case missingHost
        case invalidBase64(String)
        case invalidUTF8(String)
        case keyTooLong(actual: Int, maximum: Int)
    }

    public static func configKey(from primaryHost: URL) throws -> Data {
        guard let host = primaryHost.host, !host.isEmpty else {
            throw DerivationError.missingHost
        }
        return try paddedKey(host, length: 32)
    }

    public static func paddedKey(_ key: String, length: Int) throws -> Data {
        var bytes = Array(key.utf8)
        guard bytes.count <= length else {
            throw DerivationError.keyTooLong(actual: bytes.count, maximum: length)
        }
        bytes.append(contentsOf: repeatElement(UInt8(ascii: "0"), count: length - bytes.count))
        return Data(bytes)
    }

    public static func derivedKey(k2: String, k3: String) throws -> String {
        try decodedUTF8(k2, field: "k2") + decodedUTF8(k3, field: "k3")
    }

    private static func decodedUTF8(_ value: String, field: String) throws -> String {
        guard let data = Data(base64Encoded: value) else {
            throw DerivationError.invalidBase64(field)
        }
        guard let decoded = String(data: data, encoding: .utf8) else {
            throw DerivationError.invalidUTF8(field)
        }
        return decoded
    }
}
