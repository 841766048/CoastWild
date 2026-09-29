import XCTest
@testable import CoastWildCore

final class RemoteLoginPresentationTests: XCTestCase {
    func testIdleAndLoadingPresentation() {
        XCTAssertEqual(RemoteLoginPresentation(state: .idle, isConnected: true), .ready)
        XCTAssertEqual(RemoteLoginPresentation(state: .loading, isConnected: true), .loading)
    }

    func testAuthenticatedPresentationCarriesUserID() throws {
        let session = try RemoteSession(oauthResponse: JSONValue(any: [
            "token": "token", "userInfo": ["userId": "remote-user"], "isFirstRegister": 0,
        ]))
        XCTAssertEqual(
            RemoteLoginPresentation(
                state: .authenticated(session: session),
                isConnected: true
            ),
            .authenticated(userID: "remote-user")
        )
    }

    func testFailureUsesOfflineAlertOnlyWhenDisconnected() {
        let failure = RemoteLoginState.failed(.api(.network(.notConnectedToInternet)))
        XCTAssertEqual(RemoteLoginPresentation(state: failure, isConnected: false), .offline)
        XCTAssertEqual(RemoteLoginPresentation(state: failure, isConnected: true), .retryableFailure)
    }
}
