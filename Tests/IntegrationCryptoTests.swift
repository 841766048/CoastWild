import XCTest
@testable import CoastWildCore

final class IntegrationCryptoTests: XCTestCase {
    private let standardKey = "integration-key"

    func testEncryptJSONObjectMatchesOpenSSLVector() throws {
        let encrypted = try IntegrationCipher.encryptJSONObject(
            ["value": "coast"],
            key: standardKey
        )

        XCTAssertEqual(encrypted, "xJrCMsiAea8Qwhew0yFsB597xe1swRb8OOXjN571RH0=")
    }

    func testEncryptAndDecryptJSONObjectRoundTrip() throws {
        let input: [String: Any] = [
            "http_headers": ["locale": "zh-TW"],
            "count": 3,
            "enabled": true,
        ]

        let encrypted = try IntegrationCipher.encryptJSONObject(input, key: standardKey)
        let decrypted = try IntegrationCipher.decryptJSONObject(encrypted, key: standardKey)

        XCTAssertEqual(decrypted["count"] as? Int, 3)
        XCTAssertEqual(decrypted["enabled"] as? Bool, true)
        XCTAssertEqual(
            (decrypted["http_headers"] as? [String: String])?["locale"],
            "zh-TW"
        )
    }

    func testDecryptJSONObjectStripsResponseNewlines() throws {
        let encrypted = try IntegrationCipher.encryptJSONObject(["code": 0], key: standardKey)
        let splitIndex = encrypted.index(encrypted.startIndex, offsetBy: 8)
        let wrapped = encrypted[..<splitIndex] + "\r\n" + encrypted[splitIndex...] + "\n"

        let decrypted = try IntegrationCipher.decryptJSONObject(String(wrapped), key: standardKey)

        XCTAssertEqual(decrypted["code"] as? Int, 0)
    }

    func testDecryptJSONObjectRejectsInvalidBase64() {
        XCTAssertThrowsError(
            try IntegrationCipher.decryptJSONObject("not-base64!", key: standardKey)
        ) { error in
            XCTAssertEqual(error as? IntegrationCipher.CipherError, .invalidBase64)
        }
    }

    func testDecryptJSONObjectRejectsInvalidUTF8() {
        XCTAssertThrowsError(
            try IntegrationCipher.decryptJSONObject(
                "UJw0xQ/SUisrUYApBUqj0g==",
                key: standardKey
            )
        ) { error in
            XCTAssertEqual(error as? IntegrationCipher.CipherError, .invalidUTF8)
        }
    }

    func testDecryptJSONObjectRejectsNonJSONObject() {
        XCTAssertThrowsError(
            try IntegrationCipher.decryptJSONObject(
                "4UXEZnmB5MPrjnZFLugE8Q==",
                key: standardKey
            )
        ) { error in
            XCTAssertEqual(error as? IntegrationCipher.CipherError, .nonJSONObject)
        }
    }

    func testDecryptJSONObjectRejectsWrongKey() throws {
        let encrypted = try IntegrationCipher.encryptJSONObject(["value": "coast"], key: standardKey)

        XCTAssertThrowsError(
            try IntegrationCipher.decryptJSONObject(encrypted, key: "different-key")
        )
    }

    func testEncryptRiskJSONObjectMatchesPrettyPrintedOpenSSLVector() throws {
        let encrypted = try IntegrationCipher.encryptRiskJSONObject(
            ["timezone": "Asia/Taipei", "language": "zh-TW"],
            rawKey: "0123456789abcdef"
        )

        XCTAssertEqual(
            encrypted,
            "+/OBGXJocUjKKlIDfbR3KMn2CcP6AcUcVKclJOb5yS1q9uCf9uY6FuA2uBPC6n+VLSacaAqtdia0Tx5b0shDOA=="
        )
    }

    func testEncryptRiskJSONObjectAcceptsAESKeyLengths() throws {
        for key in [
            "0123456789abcdef",
            "0123456789abcdefghijklmn",
            "0123456789abcdefghijklmnopqrstuv",
        ] {
            XCTAssertFalse(
                try IntegrationCipher.encryptRiskJSONObject(["device": "iPhone"], rawKey: key).isEmpty
            )
        }
    }

    func testEncryptRiskJSONObjectRejectsInvalidUTF8ByteLength() {
        XCTAssertThrowsError(
            try IntegrationCipher.encryptRiskJSONObject(["device": "iPhone"], rawKey: "short-key")
        ) { error in
            XCTAssertEqual(error as? IntegrationCipher.CipherError, .invalidRiskKeyLength(9))
        }
    }

    func testEncryptJSONObjectRejectsInvalidJSON() {
        XCTAssertThrowsError(
            try IntegrationCipher.encryptJSONObject(["date": Date()], key: standardKey)
        ) { error in
            XCTAssertEqual(error as? IntegrationCipher.CipherError, .invalidJSONObject)
        }
    }
}
