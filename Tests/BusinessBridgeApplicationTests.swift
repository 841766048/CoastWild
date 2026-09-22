import XCTest
@testable import CoastWildCore

@MainActor final class BusinessBridgeApplicationTests: XCTestCase {
    func testBackgroundLoginBuildsCallbackFromReturnedSessionAndStrategy() async throws {
        let session = try RemoteSession(oauthResponse: .object([
            "token": .string("fresh-token"), "userInfo": .object(["userId": .string("fresh-user")]),
            "isFirstRegister": .number(0),
        ]))
        let strategy: JSONValue = .object(["revision": .number(2)])
        let effects = Effects()
        effects.loginState = .authenticated(session: session, strategy: strategy)
        let handler = effects.handler()
        await handler.handle(.backgroundLogin)
        XCTAssertEqual(effects.events, ["login", "bootstrap", "success"])
        XCTAssertEqual(effects.receivedSession, session)
        XCTAssertEqual(effects.receivedStrategy, strategy)
        XCTAssertEqual(effects.callback?.httpHeaders["Authorization"], "Bearer fresh-token")
    }

    func testFailedLoginIsRecoverableAndNeverSendsSuccessOrRefreshesInterface() async {
        let effects = Effects()
        effects.loginState = .failed(.api(.network(.notConnectedToInternet)))
        await effects.handler().handle(.backgroundLogin)
        XCTAssertEqual(effects.events, ["login", "failure"])
        XCTAssertNil(effects.callback)
    }

    func testConcurrentLoginResultDoesNotProduceCallbackOrError() async {
        let effects = Effects()
        effects.loginState = .loading
        await effects.handler().handle(.backgroundLogin)
        XCTAssertEqual(effects.events, ["login"])
    }

    func testLanguagePersistsNormalizedPreferenceBeforeRefresh() async {
        let effects = Effects()
        await effects.handler().handle(.setLanguage(" ZH_tw "))
        XCTAssertEqual(effects.events, ["language:zh-Hans", "refresh"])
    }

    func testLanguagePersistenceFailureDoesNotRefresh() async {
        let effects = Effects()
        effects.failPersistence = true
        await effects.handler().handle(.setLanguage("fr"))
        XCTAssertEqual(effects.events, ["language:en", "failure"])
    }

    func testLogoutAndCoinsCallExistingServices() async {
        let effects = Effects()
        let handler = effects.handler()
        await handler.handle(.logout)
        await handler.handle(.refreshEntitlements)
        XCTAssertEqual(effects.events, ["logout", "restore"])
    }

    func testNativeLogConsumesOnlyPlannedSanitizedAction() async throws {
        let effects = Effects()
        let message = "token=secret userId=user-1"
        let action = try XCTUnwrap(BusinessBridgeActionPlanner.action(for: .nativeLog(message)))
        await effects.handler().handle(action)
        XCTAssertEqual(effects.events, ["log:NativeLog:\(message.count):token=[REDACTED] userId=[REDACTED]"])
    }

    func testBootstrapCallbackPayloadContainsFreshConfigurationAndRoundTripsSafely() throws {
        let value = bootstrap(token: "token\"\\\n", strategy: .object(["revision": .number(2)]))
        let payload = try value.configurationValue()
        XCTAssertEqual(payload["http_headers"]?["Authorization"], .string("Bearer token\"\\\n"))
        XCTAssertEqual(payload["strategyData"], value.strategy)
        XCTAssertEqual(payload["encConfigData"], value.encryptedConfiguration)
        XCTAssertEqual(payload["userInfo"], value.userInfo)
        let script = try JavaScriptCallbackEncoder.backgroundLoginSuccess(payload)
        let argument = String(script.dropFirst("backgroundLoginSuccess(".count).dropLast(2))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(argument.utf8), options: .fragmentsAllowed) as? String)
        XCTAssertEqual(try JSONValue(any: JSONSerialization.jsonObject(with: Data(json.utf8))), payload)
    }

    func testLanguageRefreshUpdatesBootstrapWithoutLosingSessionOrStrategy() {
        let original = bootstrap(token: "saved", strategy: .object(["revision": .number(2)]))
        let refreshed = original.withLanguage(" ZH_tw ")
        XCTAssertEqual(refreshed.packageInfo.localeIdentifier, "zh-Hans")
        XCTAssertEqual(refreshed.httpHeaders["lang"], "zh-Hans")
        XCTAssertEqual(refreshed.httpHeaders["Authorization"], original.httpHeaders["Authorization"])
        XCTAssertEqual(refreshed.strategy, original.strategy)
        XCTAssertEqual(refreshed.userInfo, original.userInfo)
    }

    private final class Effects {
        var events: [String] = []
        var loginState: RemoteLoginState = .idle
        var receivedSession: RemoteSession?
        var receivedStrategy: JSONValue?
        var callback: BusinessWebBootstrap?
        var failPersistence = false

        func handler() -> BusinessBridgeApplicationHandler {
            BusinessBridgeApplicationHandler(
                backgroundLogin: { self.events.append("login"); return self.loginState },
                makeBootstrap: { session, strategy in
                    self.events.append("bootstrap")
                    self.receivedSession = session
                    self.receivedStrategy = strategy
                    return bootstrap(token: session.token, strategy: strategy)
                },
                sendBackgroundLoginSuccess: { self.events.append("success"); self.callback = $0 },
                logout: { self.events.append("logout") },
                refreshEntitlements: { self.events.append("restore") },
                persistLanguage: { language in
                    self.events.append("language:\(language)")
                    if self.failPersistence { throw CocoaError(.fileWriteNoPermission) }
                },
                refreshInterface: { self.events.append("refresh") },
                nativeLog: { self.events.append("log:\($0):\($1):\($2)") },
                showRecoverableFailure: { self.events.append("failure") })
        }
    }
}

private func bootstrap(token: String, strategy: JSONValue) -> BusinessWebBootstrap {
    BusinessWebBootstrap(httpHeaders: ["Authorization": "Bearer \(token)"],
        baseURLs: .init(app: "https://api.example", im: "https://im.example", log: "https://log.example",
                        privacy: "https://web.example/privacy", terms: "https://web.example/terms"),
        packageInfo: .init(localeIdentifier: "en", appName: "App", packageName: "example.app"),
        encryptedConfiguration: .object(["k2": .string("fresh-key")]), strategy: strategy,
        userInfo: .object(["userId": .string("fresh-user")]), appID: "1",
        reportSubheading: "", reportDescription: "")
}
