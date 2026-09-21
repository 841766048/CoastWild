import Foundation
import XCTest
@testable import CoastWildCore

final class RemoteSessionStoreTests: XCTestCase {
    func testOAuthResponseCreatesCompleteRequestSessionAndPreservesPayload() throws {
        let response = try oauthResponse(firstRegister: 1)

        let session = try RemoteSession(oauthResponse: response)

        XCTAssertEqual(session.token, "bearer-token")
        XCTAssertEqual(session.userID, "user-42")
        XCTAssertEqual(session.isFirstRegister, 1)
        XCTAssertTrue(session.isFirstRegistration)
        XCTAssertEqual(session.requestSession, RequestSession(token: "bearer-token", userID: "user-42"))
        let object = try JSONSerialization.jsonObject(with: session.responseData) as? [String: Any]
        XCTAssertEqual(object?["isFirstRegister"] as? Int, 1)
        XCTAssertEqual((object?["userInfo"] as? [String: Any])?["nickname"] as? String, "Walker")
    }

    func testFirstRegistrationRequiresNumericOne() throws {
        XCTAssertFalse(try RemoteSession(oauthResponse: oauthResponse(firstRegister: 0)).isFirstRegistration)
        XCTAssertFalse(try RemoteSession(oauthResponse: oauthResponse(firstRegister: 2)).isFirstRegistration)
        XCTAssertThrowsError(try RemoteSession(oauthResponse: try JSONValue(any: [
            "token": "bearer-token",
            "userInfo": ["userId": "user-42"],
            "isFirstRegister": "1",
        ])))
    }

    func testIncompleteOAuthResponseIsRejected() throws {
        for response in [
            ["token": "", "userInfo": ["userId": "user-42"], "isFirstRegister": 0],
            ["token": "bearer-token", "userInfo": ["userId": "  "], "isFirstRegister": 0],
            ["token": "bearer-token", "isFirstRegister": 0],
        ] as [[String: Any]] {
            XCTAssertThrowsError(try RemoteSession(oauthResponse: try JSONValue(any: response))) { error in
                XCTAssertEqual(error as? RemoteSessionError, .invalidOAuthResponse)
            }
        }
    }

    func testStoreRoundTripsSessionAndLoginFlagThenClearsOnlySession() async throws {
        let defaults = makeDefaults()
        let store = RemoteSessionStore(defaults: defaults)
        let session = try RemoteSession(oauthResponse: oauthResponse(firstRegister: 0))

        try await store.save(session)
        await store.markLoginSucceeded()

        let storedSession = await store.session()
        let hasLoggedIn = await store.hasLoggedInBefore()
        XCTAssertEqual(storedSession, session)
        XCTAssertTrue(hasLoggedIn)
        XCTAssertNotNil(defaults.data(forKey: "LanlinLoginData"))

        await store.clear()

        let clearedSession = await store.session()
        let retainedLoginFlag = await store.hasLoggedInBefore()
        XCTAssertNil(clearedSession)
        XCTAssertNil(defaults.data(forKey: "LanlinLoginData"))
        XCTAssertTrue(retainedLoginFlag)
    }

    func testMalformedPersistedSessionIsRemoved() async {
        let defaults = makeDefaults()
        defaults.set(Data("not-json".utf8), forKey: "LanlinLoginData")

        let store = RemoteSessionStore(defaults: defaults)

        let session = await store.session()
        XCTAssertNil(session)
        XCTAssertNil(defaults.data(forKey: "LanlinLoginData"))
    }

    private func oauthResponse(firstRegister: Int) throws -> JSONValue {
        try JSONValue(any: [
            "token": "bearer-token",
            "userInfo": ["userId": "user-42", "nickname": "Walker"],
            "isFirstRegister": firstRegister,
        ])
    }

    private func makeDefaults() -> UserDefaults {
        let name = "RemoteSessionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
