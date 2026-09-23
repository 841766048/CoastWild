import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import CoastWildCore

final class IntegrationRuntimeEpochTests: XCTestCase {
    func testConfigResponseAfterResetCannotRestoreRuntimeOrKey() async throws {
        let fixture = try makeFixture(pausing: .config)
        defer { fixture.cleanUp() }
        let request = Task { try await fixture.client.getConfig(session: .anonymous) }
        await fixture.transport.waitUntilPaused()

        await fixture.client.resetRuntime()
        await fixture.transport.resume()
        _ = try await request.value

        let snapshot = await fixture.runtime.snapshot()
        let key = await fixture.keys.key()
        XCTAssertEqual(snapshot, IntegrationRuntimeSnapshot(environment: fixture.environment))
        XCTAssertNil(key)
    }

    func testStrategyResponseAfterResetCannotRestoreRuntimeOrKey() async throws {
        let fixture = try makeFixture(pausing: .strategy, directStrategy: true)
        defer { fixture.cleanUp() }
        let request = Task { try await fixture.client.getStrategy(session: .anonymous) }
        await fixture.transport.waitUntilPaused()

        await fixture.client.resetRuntime()
        await fixture.transport.resume()
        _ = try await request.value

        let snapshot = await fixture.runtime.snapshot()
        let key = await fixture.keys.key()
        XCTAssertEqual(snapshot, IntegrationRuntimeSnapshot(environment: fixture.environment))
        XCTAssertNil(key)
    }

    func testOldConfigResponseCannotOverwriteLoginStartedAfterLogout() async throws {
        try await assertOldLoginCannotOverwriteNewLogin(pausing: .config)
    }

    func testOldStrategyResponseCannotOverwriteLoginStartedAfterLogout() async throws {
        try await assertOldLoginCannotOverwriteNewLogin(pausing: .strategy)
    }

    private func assertOldLoginCannotOverwriteNewLogin(pausing endpoint: Endpoint) async throws {
        let fixture = try makeFixture(pausing: endpoint)
        defer { fixture.cleanUp() }
        let oldLogin = Task { await fixture.coordinator.backgroundLogin(riskInfo: nil) }
        await fixture.transport.waitUntilPaused()
        await fixture.coordinator.logout()

        let newLogin = await fixture.coordinator.manualLogin(riskInfo: nil)
        guard case let .authenticated(session, strategy) = newLogin else {
            await fixture.transport.resume()
            _ = await oldLogin.value
            return XCTFail("Expected the new login to complete: \(newLogin)")
        }
        XCTAssertEqual(session.token, "new-session")
        XCTAssertEqual(strategy, .object(["generation": .string("new")]))
        let newSnapshot = await fixture.runtime.snapshot()
        XCTAssertEqual(newSnapshot.configuration["generation"], .string("new"))
        XCTAssertEqual(newSnapshot.strategy, strategy)

        await fixture.transport.resume()
        let oldResult = await oldLogin.value
        let snapshotAfterOldResponse = await fixture.runtime.snapshot()
        let keyAfterOldResponse = await fixture.keys.key()
        let savedSession = await fixture.sessions.session()
        let state = await fixture.coordinator.state()
        XCTAssertEqual(oldResult, .idle)
        XCTAssertEqual(snapshotAfterOldResponse, newSnapshot)
        XCTAssertEqual(keyAfterOldResponse, Self.newKey)
        XCTAssertEqual(savedSession, session)
        XCTAssertEqual(state, newLogin)
    }

    private enum Endpoint { case config, strategy }
    private static let oldKey = "1234567890abcdeffedcba9876543210"
    private static let newKey = "abcdefghijklmnopqrstuvwxyzaabbcc"

    private struct Fixture {
        let environment: IntegrationEnvironment
        let runtime: IntegrationRuntimeConfiguration
        let keys: IntegrationKeyStore
        let transport: EpochPausingTransport
        let client: IntegrationAPIClient
        let sessions: RemoteSessionStore
        let coordinator: RemoteSessionCoordinator
        let defaults: UserDefaults
        let suite: String

        func cleanUp() { defaults.removePersistentDomain(forName: suite) }
    }

    private func makeFixture(pausing endpoint: Endpoint, directStrategy: Bool = false) throws -> Fixture {
        let environment = try IntegrationEnvironment(
            mode: .development,
            primaryHost: "https://test-app.bigegg.work", webHost: "https://web.example.com",
            imHost: "https://im.example.com", logHost: "https://log.example.com",
            privacyURL: "https://bundled.example/privacy", termsURL: "https://bundled.example/terms",
            appStoreID: "123456", bundleIdentifier: "test.duckegg.ios",
            adjustToken: "bundled-adjust"
        )
        var steps: [EpochPausingTransport.Step] = []
        if !directStrategy {
            steps.append(.init(response: try configResponse(generation: "old", key: Self.oldKey),
                               pauses: endpoint == .config))
        }
        if endpoint == .strategy {
            if !directStrategy {
                steps.append(.init(response: try oauthResponse(generation: "old", key: Self.oldKey)))
            }
            steps.append(.init(response: try response(["generation": "old"], key: Self.oldKey), pauses: true))
        }
        steps += [
            .init(response: try configResponse(generation: "new", key: Self.newKey)),
            .init(response: try oauthResponse(generation: "new", key: Self.newKey)),
            .init(response: try response(["generation": "new"], key: Self.newKey)),
        ]
        let transport = EpochPausingTransport(steps: steps)
        let runtime = IntegrationRuntimeConfiguration(environment: environment)
        let keys = IntegrationKeyStore(initialKey: Self.oldKey)
        let client = IntegrationAPIClient(
            primaryHost: environment.primaryHost, transport: transport,
            contextProvider: EpochRequestContext(), keyStore: keys, runtimeConfiguration: runtime,
            sleeper: {}
        )
        let suite = "IntegrationRuntimeEpochTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("test-device", forKey: DeviceIdentityStore.defaultsKey)
        let sessions = RemoteSessionStore(defaults: defaults)
        let identity = DeviceIdentityStore(bundleIdentifier: environment.bundleIdentifier, defaults: defaults)
        let coordinator = RemoteSessionCoordinator(api: client, deviceIdentity: identity, sessions: sessions)
        return Fixture(environment: environment, runtime: runtime, keys: keys, transport: transport,
                       client: client, sessions: sessions, coordinator: coordinator, defaults: defaults, suite: suite)
    }

    private func configResponse(generation: String, key: String) throws -> HTTPTransportResponse {
        let ciphertext = try IntegrationCipher.encryptJSONObject([
            "generation": generation,
            "items": [["name": "app_fb_id", "data": generation + "-facebook"]],
        ], key: key)
        return try response([
            "k2": Data(key.prefix(16).utf8).base64EncodedString(),
            "k3": Data(key.suffix(16).utf8).base64EncodedString(),
            "k4": Data(ciphertext.utf8).base64EncodedString(),
        ], key: "test-app.bigegg.work")
    }

    private func oauthResponse(generation: String, key: String) throws -> HTTPTransportResponse {
        try response(["token": generation + "-session", "userInfo": ["userId": generation + "-user"],
                      "isFirstRegister": 0], key: key)
    }

    private func response(_ payload: [String: Any], key: String) throws -> HTTPTransportResponse {
        let ciphertext = try IntegrationCipher.encryptJSONObject(["code": 0, "data": payload], key: key)
        let url = URL(string: "https://test-app.bigegg.work")!
        return HTTPTransportResponse(data: Data(ciphertext.utf8),
                                     response: HTTPURLResponse(url: url, statusCode: 200,
                                                               httpVersion: nil, headerFields: nil)!)
    }
}

private struct EpochRequestContext: RequestContextProviding {
    func headers(session: RequestSession) -> [String: String] { [:] }
    func riskParameters(session: RequestSession) -> [String: String] { [:] }
}

private actor EpochPausingTransport: HTTPTransport {
    struct Step {
        let response: HTTPTransportResponse
        var pauses = false
    }

    private var steps: [Step]
    private var responseContinuation: CheckedContinuation<Void, Never>?
    private var pauseWaiters: [CheckedContinuation<Void, Never>] = []

    init(steps: [Step]) { self.steps = steps }

    func send(_ request: URLRequest) async throws -> HTTPTransportResponse {
        guard !steps.isEmpty else { throw IntegrationAPIError.invalidResponse }
        let step = steps.removeFirst()
        if step.pauses {
            await withCheckedContinuation { continuation in
                responseContinuation = continuation
                let waiters = pauseWaiters
                pauseWaiters.removeAll()
                waiters.forEach { $0.resume() }
            }
        }
        return step.response
    }

    func waitUntilPaused() async {
        guard responseContinuation == nil else { return }
        await withCheckedContinuation { pauseWaiters.append($0) }
    }

    func resume() {
        responseContinuation?.resume()
        responseContinuation = nil
    }
}
