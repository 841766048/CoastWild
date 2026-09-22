import XCTest
@testable import CoastWildCore

final class BusinessBridgeActionTests: XCTestCase {
    func testPlannerMapsEveryBusinessMessageToItsNativeAction() {
        let browserURL = URL(string: "https://example.com/browser")!
        let linkURL = URL(string: "https://example.com/link")!
        let internalPayload = InternalWebPayload(
            url: URL(string: "https://example.com/internal")!,
            showsNavigationBar: true,
            title: "Details"
        )
        let edgePan = EdgePanPayload(isEnabled: true, isLeftEdge: false)

        let mappings: [(BridgeMessage, BusinessBridgeAction)] = [
            (.backgroundLogin, .backgroundLogin),
            (.didMoveToMainPage, .revealBusinessWeb),
            (.openAppBrowser(browserURL), .presentBrowser(browserURL)),
            (.openLink(linkURL), .openExternalLink(linkURL)),
            (.openInternalWeb(internalPayload), .openInternalWeb(internalPayload)),
            (.openAppSettings, .openSettings),
            (.openAppStoreReview, .requestReview),
            (.enableEdgePan(edgePan), .setEdgePan(edgePan)),
            (.logout, .logout),
            (.updateLanguage("zh-TW"), .setLanguage("zh-Hans")),
            (.updateCoins, .refreshEntitlements),
            (.nativeLog("loaded"), .nativeLog(event: "NativeLog", messageLength: 6, summary: "loaded")),
            (.newTppClose, .callback(.closeInternalWeb)),
            (.openVipService, .callback(.openVIPService)),
            (.recharge, .callback(.recharge)),
        ]

        for (message, expectedAction) in mappings {
            XCTAssertEqual(BusinessBridgeActionPlanner.action(for: message), expectedAction)
        }
    }

    func testPlannerLeavesIAPAndCreateOrderMessagesForTheirExistingOwner() {
        let purchase = AppPurchasePayload(goodsCode: "vip.monthly", paySource: "home", invitationID: "invite")
        let log = PurchaseLogPayload(amount: 9.99, currency: "USD")

        XCTAssertNil(BusinessBridgeActionPlanner.action(for: .openAppPurchase(purchase)))
        XCTAssertNil(BusinessBridgeActionPlanner.action(for: .logPurchase(log)))
        XCTAssertNil(BusinessBridgeActionPlanner.action(for: .getProductPrice(["vip.monthly"])))
        XCTAssertNil(BusinessBridgeActionPlanner.action(for: .onCreateOrder))
    }

    func testLanguageNormalizationUsesSimplifiedChineseForChineseLocalesAndEnglishOtherwise() {
        XCTAssertEqual(BridgeLanguage.normalized("zh-Hant"), "zh-Hans")
        XCTAssertEqual(BridgeLanguage.normalized("ZH_tw"), "zh-Hans")
        XCTAssertEqual(BridgeLanguage.normalized("en-GB"), "en")
        XCTAssertEqual(BridgeLanguage.normalized("fr"), "en")
    }

    func testNativeLogSummaryStripsControlCharactersAndRedactsSensitiveValues() {
        let message = "start\nAuthorization: Bearer abc.def.ghi\u{0000} url=https://example.com/path?token=secret&locale=zh-Hans"

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            "startAuthorization: [REDACTED] url=https://example.com/path"
        )
    }

    func testNativeLogSummaryRedactsStandaloneJWSAndCapsAtOneHundredSixtyCharacters() {
        let secret = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature"
        let message = secret + String(repeating: "x", count: 200)

        let summary = BridgeNativeLog.sanitizedSummary(message)
        XCTAssertFalse(summary.contains(secret))
        XCTAssertLessThanOrEqual(summary.count, 160)
        XCTAssertTrue(summary.hasPrefix("[REDACTED]"))
    }

    func testNativeLogSummaryRedactsBasicAuthorizationCredentials() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary("Authorization: Basic dXNlcjpwYXNzd29yZA=="),
            "Authorization: [REDACTED]"
        )
    }

    func testNativeLogSummaryRedactsCaseInsensitiveSensitiveNamedFieldsWithColonAndEqualsForms() {
        let message = "TOKEN=secret DeviceId: device-123 ORDERID=order-456 Receipt: receipt-data USERINFO=profile"

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            "TOKEN=[REDACTED] DeviceId: [REDACTED] ORDERID=[REDACTED] Receipt: [REDACTED] USERINFO=[REDACTED]"
        )
    }

    func testNativeLogSummaryRedactsShortJWSLikeTokens() {
        XCTAssertEqual(BridgeNativeLog.sanitizedSummary("token eyJ9.e30.sig"), "token [REDACTED]")
    }

    func testNativeLogSummaryStripsOpaqueURLQueriesAndFragments() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary("url=https://example.com/path?opaque-query#fragment"),
            "url=https://example.com/path"
        )
    }
}
