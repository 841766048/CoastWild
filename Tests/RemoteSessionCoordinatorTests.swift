import Foundation
import XCTest
@testable import CoastWildCore

final class RemoteSessionCoordinatorTests: XCTestCase {
    func testAutomaticLoginUsesPersistedSessionAndSkipsOAuth() async throws {
        let dependencies = try makeDependencies()
        let existing = try RemoteSession(oauthResponse: oauthResponse(token: "saved", userID: "user-saved"))
        try await dependencies.sessions.save(existing)
        let coordinator = RemoteSessionCoordinator(
            api: dependencies.api,
            deviceIdentity: dependencies.identity,
            sessions: dependencies.sessions
        )

        let state = await coordinator.automaticLogin()
        let calls = await dependencies.api.calls()

        XCTAssertEqual(state, .authenticated(session: existing, strategy: .object(["route": .string("web")])) )
        XCTAssertEqual(calls, ["config:saved", "strategy:saved"])
    }

    func testManualAndBackgroundLoginUseThreeStepFlowAndReloginFlag() async throws {
        let dependencies = try makeDependencies()
        let coordinator = RemoteSessionCoordinator(
            api: dependencies.api,
            deviceIdentity: dependencies.identity,
            sessions: dependencies.sessions
        )

        let manual = await coordinator.manualLogin(riskInfo: "risk")
        let manualCalls = await dependencies.api.calls()
        XCTAssertAuthenticated(manual)
        XCTAssertEqual(manualCalls, ["config:", "oauth:device-uuid:0:risk", "strategy:remote-token"])

        await dependencies.api.resetCalls()
        let background = await coordinator.backgroundLogin(riskInfo: nil)
        let backgroundCalls = await dependencies.api.calls()
        XCTAssertAuthenticated(background)
        XCTAssertEqual(backgroundCalls, ["config:", "oauth:device-uuid:1:", "strategy:remote-token"])
    }

    func testConcurrentLoginDoesNotStartDuplicateRequests() async throws {
        let dependencies = try makeDependencies(configDelayNanoseconds: 100_000_000)
        let coordinator = RemoteSessionCoordinator(
            api: dependencies.api,
            deviceIdentity: dependencies.identity,
            sessions: dependencies.sessions
        )

        let first = Task { await coordinator.manualLogin(riskInfo: nil) }
        try await Task.sleep(nanoseconds: 10_000_000)
        let duplicate = await coordinator.manualLogin(riskInfo: nil)
        _ = await first.value
        let calls = await dependencies.api.calls()

        XCTAssertEqual(duplicate, .loading)
        XCTAssertEqual(calls, ["config:", "oauth:device-uuid:0:", "strategy:remote-token"])
    }

    func testStrategyFailureKeepsNewSessionAndLogoutRetainsDeviceIdentity() async throws {
        let dependencies = try makeDependencies(strategyError: .network(.notConnectedToInternet))
        let coordinator = RemoteSessionCoordinator(
            api: dependencies.api,
            deviceIdentity: dependencies.identity,
            sessions: dependencies.sessions
        )

        let state = await coordinator.manualLogin(riskInfo: nil)
        let storedAfterFailure = await dependencies.sessions.session()

        XCTAssertEqual(state, .failed(.api(.network(.notConnectedToInternet))))
        XCTAssertEqual(storedAfterFailure?.token, "remote-token")

        await coordinator.logout()
        let clearedSession = await dependencies.sessions.sessionValueForTest()
        let retainedIdentity = try dependencies.identity.resolve()

        XCTAssertNil(clearedSession)
        XCTAssertEqual(retainedIdentity, "device-uuid")
    }

    func testInvalidOAuthDoesNotReplaceExistingSession() async throws {
        let dependencies = try makeDependencies(oauthResponse: .object(["token": .string("")]))
        let existing = try RemoteSession(oauthResponse: oauthResponse(token: "saved", userID: "existing"))
        try await dependencies.sessions.save(existing)
        let coordinator = RemoteSessionCoordinator(
            api: dependencies.api,
            deviceIdentity: dependencies.identity,
            sessions: dependencies.sessions
        )

        let state = await coordinator.manualLogin(riskInfo: nil)
        let stored = await dependencies.sessions.session()

        XCTAssertEqual(state, .failed(.invalidOAuthResponse))
        XCTAssertEqual(stored, existing)
    }

    private func makeDependencies(
        oauthResponse: JSONValue? = nil,
        strategyError: IntegrationAPIError? = nil,
        configDelayNanoseconds: UInt64 = 0
    ) throws -> (api: RemoteAPIFake, identity: DeviceIdentityStore, sessions: RemoteSessionStore) {
        let defaults = makeDefaults()
        defaults.set("device-uuid", forKey: DeviceIdentityStore.defaultsKey)
        let identity = DeviceIdentityStore(
            bundleIdentifier: "test.duckegg.ios",
            defaults: defaults,
            keychain: EmptyKeychain()
        )
        let sessions = RemoteSessionStore(defaults: defaults)
        let resolvedResponse: JSONValue
        if let oauthResponse {
            resolvedResponse = oauthResponse
        } else {
            resolvedResponse = try self.oauthResponse(token: "remote-token", userID: "remote-user")
        }
        let api = RemoteAPIFake(
            oauthResponse: resolvedResponse,
            strategyError: strategyError,
            configDelayNanoseconds: configDelayNanoseconds
        )
        return (api, identity, sessions)
    }

    private func oauthResponse(token: String, userID: String) throws -> JSONValue {
        try JSONValue(any: [
            "token": token,
            "userInfo": ["userId": userID],
            "isFirstRegister": 0,
        ])
    }

    private func makeDefaults() -> UserDefaults {
        let name = "RemoteSessionCoordinatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func XCTAssertAuthenticated(
        _ state: RemoteLoginState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .authenticated = state else {
            return XCTFail("Expected authenticated, got \(state)", file: file, line: line)
        }
    }
}

private actor RemoteAPIFake: RemoteAuthenticationAPI {
    private var callLog: [String] = []
    private let response: JSONValue
    private let strategyError: IntegrationAPIError?
    private let configDelayNanoseconds: UInt64

    init(oauthResponse: JSONValue, strategyError: IntegrationAPIError?, configDelayNanoseconds: UInt64) {
        response = oauthResponse
        self.strategyError = strategyError
        self.configDelayNanoseconds = configDelayNanoseconds
    }

    func getConfig(session: RequestSession) async throws -> IntegrationConfigBundle {
        callLog.append("config:\(session.token)")
        if configDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: configDelayNanoseconds)
        }
        return IntegrationConfigBundle(k2: "", k3: "", k4: "", configuration: .object([:]))
    }

    func oauth(_ request: OAuthRequest, session: RequestSession) async throws -> JSONValue {
        callLog.append("oauth:\(request.token):\(request.relogin ? 1 : 0):\(request.riskInfo ?? "")")
        return response
    }

    func getStrategy(session: RequestSession) async throws -> JSONValue {
        callLog.append("strategy:\(session.token)")
        if let strategyError { throw strategyError }
        return .object(["route": .string("web")])
    }

    func calls() -> [String] { callLog }
    func resetCalls() { callLog = [] }
}

private struct EmptyKeychain: KeychainValueStoring {
    func read(account: String) throws -> String? { nil }
    func write(_ value: String, account: String, accessibility: KeychainAccessibility) throws {}
}

private extension RemoteSessionStore {
    func sessionValueForTest() -> RemoteSession? { session() }
}
