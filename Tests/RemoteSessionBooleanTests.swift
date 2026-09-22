import XCTest
@testable import CoastWildCore

final class RemoteSessionBooleanTests: XCTestCase {
    func testRealOAuthBooleanRegistrationFlagIsAcceptedAndPreserved() throws {
        for flag in [true, false] {
            let response = try JSONValue(any: ["token": "session", "userInfo": ["userId": "user"], "isFirstRegister": flag])
            let session = try RemoteSession(oauthResponse: response)
            XCTAssertEqual(session.isFirstRegistration, flag)
            XCTAssertEqual(session.isFirstRegister, flag ? 1 : 0)
            let saved = try JSONValue(any: JSONSerialization.jsonObject(with: session.responseData))
            XCTAssertEqual(saved["isFirstRegister"], .bool(flag))
        }
    }
}
