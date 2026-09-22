import CommonCrypto
import Foundation

public enum IntegrationCipher {
    public enum CipherError: Error, Equatable, Sendable {
        case invalidJSONObject
        case invalidStandardKey
        case invalidRiskKeyLength(Int)
        case invalidBase64
        case cryptFailed
        case invalidUTF8
        case nonJSONObject
    }

    public static func encryptJSONObject(
        _ object: [String: Any],
        key: String
    ) throws -> String {
        let input = try jsonData(object, prettyPrinted: false)
        let keyData: Data
        do {
            keyData = try IntegrationKeyDeriver.paddedKey(key, length: kCCKeySizeAES256)
        } catch {
            throw CipherError.invalidStandardKey
        }
        return try crypt(input, key: keyData, operation: CCOperation(kCCEncrypt))
            .base64EncodedString()
    }

    public static func decryptJSONObject(
        _ base64: String,
        key: String
    ) throws -> [String: Any] {
        let cleaned = base64
            .replacingOccurrences(of: "\r\n", with: "")
            .replacingOccurrences(of: "\n", with: "")
        guard let encrypted = Data(base64Encoded: cleaned) else {
            throw CipherError.invalidBase64
        }

        let keyData: Data
        do {
            keyData = try IntegrationKeyDeriver.paddedKey(key, length: kCCKeySizeAES256)
        } catch {
            throw CipherError.invalidStandardKey
        }
        let decrypted = try crypt(encrypted, key: keyData, operation: CCOperation(kCCDecrypt))
        guard let json = String(data: decrypted, encoding: .utf8) else {
            throw CipherError.invalidUTF8
        }
        guard let value = try? JSONSerialization.jsonObject(with: Data(json.utf8)),
              let object = value as? [String: Any]
        else {
            throw CipherError.nonJSONObject
        }
        return object
    }

    public static func encryptRiskJSONObject(
        _ object: [String: Any],
        rawKey: String
    ) throws -> String {
        let keyData = Data(rawKey.utf8)
        guard [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(keyData.count) else {
            throw CipherError.invalidRiskKeyLength(keyData.count)
        }
        let input = try jsonData(object, prettyPrinted: true)
        return try crypt(input, key: keyData, operation: CCOperation(kCCEncrypt))
            .base64EncodedString()
    }

    private static func jsonData(
        _ object: [String: Any],
        prettyPrinted: Bool
    ) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw CipherError.invalidJSONObject
        }
        var options: JSONSerialization.WritingOptions = [.sortedKeys]
        if prettyPrinted {
            options.insert(.prettyPrinted)
        }
        do {
            return try JSONSerialization.data(withJSONObject: object, options: options)
        } catch {
            throw CipherError.invalidJSONObject
        }
    }

    private static func crypt(
        _ input: Data,
        key: Data,
        operation: CCOperation
    ) throws -> Data {
        let outputCapacity = input.count + kCCBlockSizeAES128
        var output = Data(count: outputCapacity)
        var outputLength = 0
        let status = output.withUnsafeMutableBytes { outputBytes in
            input.withUnsafeBytes { inputBytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                        keyBytes.baseAddress,
                        key.count,
                        nil,
                        inputBytes.baseAddress,
                        input.count,
                        outputBytes.baseAddress,
                        outputCapacity,
                        &outputLength
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw CipherError.cryptFailed
        }
        output.removeSubrange(outputLength..<output.count)
        return output
    }
}
