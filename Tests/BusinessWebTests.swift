import XCTest
@testable import CoastWildCore

final class BusinessWebTests: XCTestCase {
    func testBootstrapSerializesFourDocumentStartValuesWithoutExecutableStringConcatenation() throws {
        let bootstrap = BusinessWebBootstrap(
            httpHeaders: ["Authorization": "Bearer token", "X-Quote": "\";window.pwned=true;//"],
            baseURLs: .init(
                app: "https://app.example.com", im: "https://im.example.com",
                log: "https://log.example.com", privacy: "https://example.com/privacy",
                terms: "https://example.com/terms"
            ),
            packageInfo: .init(localeIdentifier: "en_US", appName: "Coast & Wild", packageName: "com.example.app"),
            encryptedConfiguration: .object(["k2": .string("two")]),
            strategy: .object(["route": .string("home")]),
            userInfo: .object(["userId": .string("user-1")]),
            appID: "123456789",
            reportSubheading: "Report \"content\"",
            reportDescription: "Line one\nLine two"
        )

        let script = try bootstrap.javaScript(
            webLoadTimeMilliseconds: 1_727_000_123_456,
            safeAreaInsets: .init(top: 59, bottom: 34, left: 0, right: 0),
            appIconDataURL: "data:image/jpeg;base64,abc123"
        )

        XCTAssertTrue(script.contains("window.appConfigOptions="))
        XCTAssertTrue(script.contains("window.webLoadTime=1727000123456;"))
        XCTAssertTrue(script.contains("window.safeAreaInsets={\"bottom\":34,\"left\":0,\"right\":0,\"top\":59};"))
        XCTAssertTrue(script.contains("window.appIconBase64=\"data:image\\/jpeg;base64,abc123\";"))
        XCTAssertTrue(script.contains("\\\";window.pwned=true;\\/\\/"))
        XCTAssertFalse(script.contains("X-Quote\":\"\";window.pwned=true;//"))
        XCTAssertTrue(script.contains("\"nativeWebIndexHandled\":\"1\""))
        XCTAssertTrue(script.contains("\"supportGetLocalPrice\":\"1\""))
    }

    func testBootstrapEscapesJavaScriptLineSeparators() throws {
        let bootstrap = fixtureBootstrap(reportDescription: "before\u{2028}after\u{2029}done")
        let script = try bootstrap.javaScript(
            webLoadTimeMilliseconds: 1,
            safeAreaInsets: .zero,
            appIconDataURL: ""
        )
        XCTAssertFalse(script.contains("\u{2028}"))
        XCTAssertFalse(script.contains("\u{2029}"))
        XCTAssertTrue(script.contains("\\u2028"))
        XCTAssertTrue(script.contains("\\u2029"))
    }

    func testNavigationPolicyAllowsOnlyConfiguredHTTPSHosts() {
        let policy = BusinessWebNavigationPolicy(allowedHosts: ["h5.example.com", "cdn.example.com"])
        XCTAssertEqual(policy.decision(for: URL(string: "https://h5.example.com/home")!), .allow)
        XCTAssertEqual(policy.decision(for: URL(string: "https://cdn.example.com/asset")!), .allow)
        XCTAssertEqual(policy.decision(for: URL(string: "http://h5.example.com/home")!), .deny)
        XCTAssertEqual(policy.decision(for: URL(string: "https://evil.example/home")!), .deny)
        XCTAssertEqual(policy.decision(for: URL(string: "https://sub.h5.example.com/home")!), .deny)
    }

    func testNavigationPolicyRoutesApprovedExternalSchemesAndRejectsUnknownOnes() {
        let policy = BusinessWebNavigationPolicy(allowedHosts: ["h5.example.com"])
        for value in ["tel:+15551234567", "mailto:help@example.com", "itms-apps://apps.apple.com/app/id1"] {
            let url = URL(string: value)!
            XCTAssertEqual(policy.decision(for: url), .openExternal(url))
        }
        XCTAssertEqual(policy.decision(for: URL(string: "javascript:alert(1)")!), .deny)
        XCTAssertEqual(policy.decision(for: URL(string: "file:///tmp/private")!), .deny)
        XCTAssertEqual(policy.decision(for: nil), .deny)
    }

    func testBridgeBrowserAndExternalActionsAcceptOnlyHTTPSURLs() {
        let policy = BusinessWebNavigationPolicy(allowedHosts: ["h5.example.com"])
        let httpsURL = URL(string: "https://outside.example/help")!
        let httpURL = URL(string: "http://outside.example/help")!

        XCTAssertEqual(policy.validatedURL(for: .presentBrowser(httpsURL)), httpsURL)
        XCTAssertEqual(policy.validatedURL(for: .openExternalLink(httpsURL)), httpsURL)
        XCTAssertNil(policy.validatedURL(for: .presentBrowser(httpURL)))
        XCTAssertNil(policy.validatedURL(for: .openExternalLink(httpURL)))
        XCTAssertNil(policy.validatedURL(for: .openSettings))
    }

    func testBusinessWebRevealIsIdempotentUntilANewLoadBegins() {
        var state = BusinessWebLocalActionState()

        XCTAssertTrue(state.reveal())
        XCTAssertTrue(state.isRevealed)
        XCTAssertFalse(state.reveal())

        state.beginLoading()

        XCTAssertFalse(state.isRevealed)
        XCTAssertTrue(state.reveal())
    }

    func testEdgePanStatePreservesEnabledFlagAndRequestedEdge() {
        var state = BusinessWebLocalActionState()
        let rightEdge = EdgePanPayload(isEnabled: true, isLeftEdge: false)
        let disabledLeftEdge = EdgePanPayload(isEnabled: false, isLeftEdge: true)

        state.setEdgePan(rightEdge)
        XCTAssertEqual(state.edgePan, rightEdge)

        state.setEdgePan(disabledLeftEdge)
        XCTAssertEqual(state.edgePan, disabledLeftEdge)
    }

    func testNativeLogDeliveryNeverUsesRawLegacyFallback() throws {
        let secret = "token=super-secret"
        let message = BridgeMessage.nativeLog(secret)
        let action = try XCTUnwrap(BusinessBridgeActionPlanner.action(for: message))

        XCTAssertEqual(
            BusinessBridgeApplicationDeliveryPolicy.delivery(
                action: action, originalMessage: message, hasActionSink: true),
            .action(action)
        )
        XCTAssertEqual(
            BusinessBridgeApplicationDeliveryPolicy.delivery(
                action: action, originalMessage: message, hasActionSink: false),
            .discard
        )
        XCTAssertNotEqual(
            BusinessBridgeApplicationDeliveryPolicy.delivery(
                action: action, originalMessage: message, hasActionSink: false),
            .legacyMessage(message)
        )
    }

    func testNonSensitiveApplicationActionCanUseLegacyFallbackWithoutActionSink() {
        XCTAssertEqual(
            BusinessBridgeApplicationDeliveryPolicy.delivery(
                action: .logout, originalMessage: .logout, hasActionSink: false),
            .legacyMessage(.logout)
        )
    }

    func testVisibleLeftEdgeWebBackMakesCurrentNavigationPopWait() {
        let enabledLeft = EdgePanPayload(isEnabled: true, isLeftEdge: true)

        XCTAssertEqual(
            BusinessWebEdgePanPolicy.decision(
                payload: enabledLeft,
                webCanGoBack: true,
                isNavigationRoot: false,
                isControllerVisible: true,
                isOtherRecognizerCurrentNavigationPop: true),
            .init(
                shouldEnableRecognizer: true,
                shouldBeginWebGesture: true,
                shouldNavigationPopWaitForWebGesture: true)
        )
        XCTAssertEqual(
            BusinessWebEdgePanPolicy.decision(
                payload: enabledLeft,
                webCanGoBack: false,
                isNavigationRoot: false,
                isControllerVisible: true,
                isOtherRecognizerCurrentNavigationPop: true),
            .init(
                shouldEnableRecognizer: true,
                shouldBeginWebGesture: false,
                shouldNavigationPopWaitForWebGesture: false)
        )
    }

    func testHiddenOrDisabledControllerCannotClaimEdgePriority() {
        let enabledLeft = EdgePanPayload(isEnabled: true, isLeftEdge: true)
        let disabledLeft = EdgePanPayload(isEnabled: false, isLeftEdge: true)

        XCTAssertEqual(
            BusinessWebEdgePanPolicy.decision(
                payload: enabledLeft,
                webCanGoBack: true,
                isNavigationRoot: false,
                isControllerVisible: false,
                isOtherRecognizerCurrentNavigationPop: true),
            .init(
                shouldEnableRecognizer: false,
                shouldBeginWebGesture: false,
                shouldNavigationPopWaitForWebGesture: false)
        )
        XCTAssertEqual(
            BusinessWebEdgePanPolicy.decision(
                payload: disabledLeft,
                webCanGoBack: true,
                isNavigationRoot: false,
                isControllerVisible: true,
                isOtherRecognizerCurrentNavigationPop: true),
            .init(
                shouldEnableRecognizer: false,
                shouldBeginWebGesture: false,
                shouldNavigationPopWaitForWebGesture: false)
        )
    }

    func testRootRightEdgeAndUnrelatedRecognizerDoNotCreateFailurePriority() {
        let enabledLeft = EdgePanPayload(isEnabled: true, isLeftEdge: true)
        let enabledRight = EdgePanPayload(isEnabled: true, isLeftEdge: false)

        XCTAssertEqual(
            BusinessWebEdgePanPolicy.decision(
                payload: enabledLeft,
                webCanGoBack: true,
                isNavigationRoot: true,
                isControllerVisible: true,
                isOtherRecognizerCurrentNavigationPop: true),
            .init(
                shouldEnableRecognizer: true,
                shouldBeginWebGesture: true,
                shouldNavigationPopWaitForWebGesture: false)
        )
        XCTAssertEqual(
            BusinessWebEdgePanPolicy.decision(
                payload: enabledRight,
                webCanGoBack: true,
                isNavigationRoot: false,
                isControllerVisible: true,
                isOtherRecognizerCurrentNavigationPop: true),
            .init(
                shouldEnableRecognizer: true,
                shouldBeginWebGesture: true,
                shouldNavigationPopWaitForWebGesture: false)
        )
        XCTAssertEqual(
            BusinessWebEdgePanPolicy.decision(
                payload: enabledLeft,
                webCanGoBack: true,
                isNavigationRoot: false,
                isControllerVisible: true,
                isOtherRecognizerCurrentNavigationPop: false),
            .init(
                shouldEnableRecognizer: true,
                shouldBeginWebGesture: true,
                shouldNavigationPopWaitForWebGesture: false)
        )
    }

    func testInternalWebContractIsIsolatedAndOnlyRegistersCloseMessage() {
        XCTAssertTrue(InternalWebContract.usesDedicatedWebViewConfiguration)
        XCTAssertFalse(InternalWebContract.injectsBusinessBootstrap)
        XCTAssertEqual(InternalWebContract.messageNames, ["newTppClose"])
    }

    func testInternalWebVisibilityCallbackUsesExactShowAndHideValues() {
        XCTAssertEqual(InternalWebContract.visibilityJavaScript(isVisible: true), "innerWebShow(\"1\");")
        XCTAssertEqual(InternalWebContract.visibilityJavaScript(isVisible: false), "innerWebShow(\"0\");")
    }

    private func fixtureBootstrap(reportDescription: String) -> BusinessWebBootstrap {
        BusinessWebBootstrap(
            httpHeaders: [:],
            baseURLs: .init(app: "https://a.example", im: "https://i.example", log: "https://l.example", privacy: "https://p.example", terms: "https://t.example"),
            packageInfo: .init(localeIdentifier: "en", appName: "App", packageName: "com.example"),
            encryptedConfiguration: .object([:]), strategy: .object([:]), userInfo: .object([:]),
            appID: "1", reportSubheading: "", reportDescription: reportDescription
        )
    }
}
