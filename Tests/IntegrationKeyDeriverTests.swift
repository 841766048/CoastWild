import XCTest
@testable import CoastWildCore

final class IntegrationKeyDeriverTests: XCTestCase {
    func testConfigKeyUsesOnlyHost() throws {
        let key = try IntegrationKeyDeriver.configKey(
            from: URL(string: "https://api.example.com/v1/config?source=ios")!
        )

        XCTAssertEqual(String(decoding: key, as: UTF8.self), "api.example.com00000000000000000")
        XCTAssertEqual(key.count, 32)
    }

    func testPaddedKeyUsesASCIIZeroBytes() throws {
        let key = try IntegrationKeyDeriver.paddedKey("abc", length: 8)

        XCTAssertEqual(Array(key), [97, 98, 99, 48, 48, 48, 48, 48])
    }

    func testPaddedKeyRejectsInputLongerThanRequestedLength() {
        XCTAssertThrowsError(try IntegrationKeyDeriver.paddedKey("12345", length: 4)) { error in
            XCTAssertEqual(
                error as? IntegrationKeyDeriver.DerivationError,
                .keyTooLong(actual: 5, maximum: 4)
            )
        }
    }

    func testDerivedKeyConcatenatesDecodedK2AndK3() throws {
        let key = try IntegrationKeyDeriver.derivedKey(
            k2: Data("coast-".utf8).base64EncodedString(),
            k3: Data("wild".utf8).base64EncodedString()
        )

        XCTAssertEqual(key, "coast-wild")
    }

    func testDerivedKeyRejectsInvalidBase64() {
        XCTAssertThrowsError(
            try IntegrationKeyDeriver.derivedKey(k2: "not base64!", k3: "d2lsZA==")
        ) { error in
            XCTAssertEqual(error as? IntegrationKeyDeriver.DerivationError, .invalidBase64("k2"))
        }
    }
}
