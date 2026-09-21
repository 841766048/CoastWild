import XCTest
@testable import CoastWildCore

final class BridgeTests: XCTestCase {
    func testAllNineteenTopicsAreDeclared() {
        XCTAssertEqual(Set(BridgeTopic.allCases.map(\.rawValue)), Set([
            "OpenAppPurchase", "LogPurchase", "onCreateOrder", "GetProductPrice",
            "Logout", "BackgroundLogin", "DidMoveToMainPage",
            "OpenAppBrowser", "OpenLink", "OpenInternalWeb", "OpenAppSettings",
            "OpenAppStoreReview", "EnableEdgePan", "newTppClose", "openVipService",
            "recharge", "UpdateCoins", "UpdateLanguage", "NativeLog",
        ]))
    }

    func testPayloadDecoderAcceptsValidTypedPayloads() throws {
        XCTAssertEqual(try BridgeMessage.decode(topic: .openAppBrowser, body: "https://example.com/help"), .openAppBrowser(URL(string: "https://example.com/help")!))
        XCTAssertEqual(try BridgeMessage.decode(topic: .openLink, body: "https://example.com"), .openLink(URL(string: "https://example.com")!))
        XCTAssertEqual(try BridgeMessage.decode(topic: .openInternalWeb, body: ["url": "https://example.com/inside", "show": "0", "title": "Inside"]), .openInternalWeb(.init(url: URL(string: "https://example.com/inside")!, showsNavigationBar: false, title: "Inside")))
        XCTAssertEqual(try BridgeMessage.decode(topic: .logPurchase, body: ["paidAmount": 9.99, "paidCurrency": "USD"]), .logPurchase(.init(amount: 9.99, currency: "USD")))
        XCTAssertEqual(try BridgeMessage.decode(topic: .enableEdgePan, body: ["enable": "1", "left": "0"]), .enableEdgePan(.init(isEnabled: true, isLeftEdge: false)))
        XCTAssertEqual(try BridgeMessage.decode(topic: .openAppPurchase, body: ["goodsCode": "sku.monthly", "paySource": "home", "invitationId": "invite"]), .openAppPurchase(.init(goodsCode: "sku.monthly", paySource: "home", invitationID: "invite")))
        XCTAssertEqual(try BridgeMessage.decode(topic: .getProductPrice, body: ["productIds": "sku.one,sku.two"]), .getProductPrice(["sku.one", "sku.two"]))
        XCTAssertEqual(try BridgeMessage.decode(topic: .updateLanguage, body: "en"), .updateLanguage("en"))
        XCTAssertEqual(try BridgeMessage.decode(topic: .nativeLog, body: "loaded"), .nativeLog("loaded"))
        for topic in BridgeTopic.allCases.filter({ $0.acceptsEmptyBody }) {
            XCTAssertNoThrow(try BridgeMessage.decode(topic: topic, body: nil))
        }
    }

    func testPayloadDecoderRejectsInvalidURLsMoneyCurrencyFlagsAndSKUs() {
        assertInvalid(.openAppBrowser, "http://example.com", field: "url")
        assertInvalid(.openInternalWeb, ["url": "https://example.com", "show": "yes"], field: "show")
        assertInvalid(.logPurchase, ["paidAmount": -1, "paidCurrency": "usd"], field: "paidAmount")
        assertInvalid(.logPurchase, ["paidAmount": 1, "paidCurrency": "US"], field: "paidCurrency")
        assertInvalid(.enableEdgePan, ["enable": "2", "left": "1"], field: "enable")
        assertInvalid(.openAppPurchase, ["goodsCode": "bad sku", "paySource": "home", "invitationId": ""], field: "goodsCode")
        assertInvalid(.getProductPrice, ["productIds": "sku.one,,bad sku"], field: "productIds")
        assertInvalid(.updateLanguage, "", field: "language")
    }

    func testRouterRejectsUnknownUntrustedSubframeAndUnsupportedTopic() {
        let handler = BridgeHandlerSpy()
        let router = BridgeRouter(allowedHosts: ["h5.example.com"], handler: handler)
        XCTAssertThrowsError(try router.route(name: "Unknown", body: nil, sourceURL: URL(string: "https://h5.example.com"), isMainFrame: true)) { XCTAssertEqual($0 as? BridgeError, .unknownTopic("Unknown")) }
        XCTAssertThrowsError(try router.route(name: "Logout", body: nil, sourceURL: URL(string: "https://evil.example"), isMainFrame: true)) { XCTAssertEqual($0 as? BridgeError, .untrustedSource) }
        XCTAssertThrowsError(try router.route(name: "Logout", body: nil, sourceURL: URL(string: "https://h5.example.com"), isMainFrame: false)) { XCTAssertEqual($0 as? BridgeError, .untrustedFrame) }
        XCTAssertThrowsError(try router.route(name: "onCreateOrder", body: nil, sourceURL: URL(string: "https://h5.example.com"), isMainFrame: true)) { XCTAssertEqual($0 as? BridgeError, .unsupported(.onCreateOrder)) }
        XCTAssertTrue(handler.messages.isEmpty)
    }

    func testRouterDispatchesExactlyOneDecodedMessage() throws {
        let handler = BridgeHandlerSpy()
        let router = BridgeRouter(allowedHosts: ["h5.example.com"], handler: handler)
        try router.route(name: "Logout", body: nil, sourceURL: URL(string: "https://h5.example.com/home"), isMainFrame: true)
        XCTAssertEqual(handler.messages, [.logout])
    }

    func testCallbackEncoderEscapesBackslashQuoteNewlineAndUnicode() throws {
        let value = JSONValue.object(["text": .string("slash\\ quote\" line\n海")])
        let callback = try JavaScriptCallbackEncoder.backgroundLoginSuccess(value)
        XCTAssertEqual(callback, "backgroundLoginSuccess(\"{\\\"text\\\":\\\"slash\\\\\\\\ quote\\\\\\\" line\\\\n海\\\"}\");")
        XCTAssertEqual(JavaScriptCallbackEncoder.innerWebShow(isVisible: true), "innerWebShow(\"1\");")
        XCTAssertEqual(JavaScriptCallbackEncoder.closeInternalWeb(), "newTppClose();")
    }

    func testLifecycleAndKeyboardEventJavaScriptUsesRequiredDetailKeys() {
        XCTAssertEqual(BridgeEventEncoder.lifecycle(.resumed), "window.dispatchEvent(new CustomEvent(\"AppLifecycleState\",{detail:{result:\"resumed\"}}));")
        XCTAssertEqual(BridgeEventEncoder.lifecycle(.paused), "window.dispatchEvent(new CustomEvent(\"AppLifecycleState\",{detail:{result:\"paused\"}}));")
        XCTAssertEqual(BridgeEventEncoder.keyboard(height: 301.5, duration: 0.25), "window.dispatchEvent(new CustomEvent(\"KeyboardInset\",{detail:{height:301.5,duration:0.25}}));")
    }

    func testLifecycleEmitterRemovesObserversWhenReleased() {
        let center = NotificationCenter()
        let resumed = Notification.Name("bridge.resumed")
        let paused = Notification.Name("bridge.paused")
        var scripts: [String] = []
        var emitter: BridgeEventEmitter? = BridgeEventEmitter(
            center: center, resumedName: resumed, pausedName: paused,
            evaluate: { scripts.append($0) }
        )
        center.post(name: resumed, object: nil)
        XCTAssertEqual(scripts, [BridgeEventEncoder.lifecycle(.resumed)])
        weak var released = emitter
        emitter = nil
        XCTAssertNil(released)
        center.post(name: paused, object: nil)
        XCTAssertEqual(scripts.count, 1)
    }

    private func assertInvalid(_ topic: BridgeTopic, _ body: Any?, field: String) {
        XCTAssertThrowsError(try BridgeMessage.decode(topic: topic, body: body)) {
            XCTAssertEqual($0 as? BridgeError, .invalidPayload(topic, field))
        }
    }
}

private final class BridgeHandlerSpy: BridgeMessageHandling {
    var messages: [BridgeMessage] = []
    func handle(_ message: BridgeMessage) { messages.append(message) }
}
