import XCTest
@testable import CoastWildCore

final class StartupRouteTests: XCTestCase {
    func testNoSessionRequiresLogin() {
        XCTAssertEqual(StartupRoute(state: .idle), .login)
    }
    func testUnauthorizedSessionRequiresLoginButNetworkFailureDoesNot() {
        XCTAssertEqual(StartupRoute(state: .failed(.api(.httpStatus(401)))), .login)
        XCTAssertEqual(StartupRoute(state: .failed(.api(.network(.notConnectedToInternet)))), .retry)
        XCTAssertEqual(StartupRoute(state: .failed(.api(.httpStatus(500)))), .retry)
    }
    func testPendingRecoveryKeepsLaunchScreen() {
        XCTAssertEqual(StartupRoute(state: .loading), .loading)
    }
    func testFailureOffersRetryWithoutDiscardingSession() {
        XCTAssertEqual(StartupRoute(state: .failed(.unexpected)), .retry)
    }
    func testRecoveredSessionGoesDirectlyToBusiness() throws {
        let session = try RemoteSession(oauthResponse: .object([
            "token": .string("test"), "userInfo": .object(["userId": .string("user")]),
            "isFirstRegister": .number(0)
        ]))
        XCTAssertEqual(StartupRoute(state: .authenticated(session: session, strategy: .object([:]))), .business)
    }
}
