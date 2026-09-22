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
            "start Authorization: [REDACTED]  url=https://example.com/path"
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
        XCTAssertEqual(BridgeNativeLog.sanitizedSummary("token eyJhbGciOiJub25lIn0.e30.sig"), "token [REDACTED]")
    }

    func testNativeLogSummaryStripsOpaqueURLQueriesAndFragments() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary("url=https://example.com/path?opaque-query#fragment"),
            "url=https://example.com/path"
        )
    }

    func testNativeLogSummaryRecursivelyRedactsSensitiveJSONKeys() {
        let message = #"{"token":"secret","receipt":"receipt-data","userInfo":{"userId":"user-7","name":"Ada"}}"#

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            #"{"receipt":"[REDACTED]","token":"[REDACTED]","userInfo":"[REDACTED]"}"#
        )
    }

    func testNativeLogSummaryRedactsJSONObjectsEmbeddedInOrdinaryText() {
        let message = #"response: {"token":"secret","userInfo":{"name":"Ada","email":"private@example.com"}} version 1.2.3 api.example.com"#

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            #"response: {"token":"[REDACTED]","userInfo":"[REDACTED]"} version 1.2.3 api.example.com"#
        )
    }

    func testNativeLogSummaryRedactsEmbeddedJSONArrayAfterNonJSONBraces() {
        let message = #"response {ready}: [{"access_token":"secret","userInfo":{"name":"Ada"}},{"label":"a } brace"}] done"#

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            #"response {ready}: [{"access_token":"[REDACTED]","userInfo":"[REDACTED]"},{"label":"a } brace"}] done"#
        )
    }

    func testNativeLogSummaryRedactsJSONContainersUsedAsSensitiveNamedValues() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(#"ready userInfo={"name":"Ada","roles":["member"]} version 1.2.3"#),
            "ready userInfo=[REDACTED] version 1.2.3"
        )
    }

    func testNativeLogSummaryStripsURLQueriesContainingJSONContainers() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(#"url=https://api.example.com/path?context={"name":"Ada"} version 1.2.3"#),
            "url=https://api.example.com/path version 1.2.3"
        )
    }

    func testNativeLogSummaryDoesNotExpandJSONTextIntoAnotherRedactedContainer() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(#"response: {"note":"\u005f_BRIDGE_JSON_1__"} userInfo={"name":"Ada"}"#),
            #"response: {"note":"__BRIDGE_JSON_1__"} userInfo=[REDACTED]"#
        )
    }

    func testNativeLogSummaryRecursivelyRedactsJSONStringValuesContainingJSON() {
        let message = #"{"note":"response: {\"token\":\"secret\",\"userInfo\":{\"name\":\"Ada\"}}","label":"1.2.3 api.example.com"}"#

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            #"{"label":"1.2.3 api.example.com","note":"response: {\"token\":\"[REDACTED]\",\"userInfo\":\"[REDACTED]\"}"}"#
        )
    }

    func testNativeLogSummaryRedactsMultipleLayersOfJSONStringEncoding() throws {
        let inner = #"{"note":"{\"userInfo\":{\"name\":\"Ada\"}}"}"#
        let messageData = try JSONSerialization.data(withJSONObject: ["note": inner], options: [.sortedKeys])
        let message = try XCTUnwrap(String(data: messageData, encoding: .utf8))
        let expectedInner = #"{"note":"{\"userInfo\":\"[REDACTED]\"}"}"#
        let expectedData = try JSONSerialization.data(withJSONObject: ["note": expectedInner], options: [.sortedKeys])

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            try XCTUnwrap(String(data: expectedData, encoding: .utf8))
        )
    }

    func testNativeLogSummaryRedactsEmbeddedJSONInAJSONStringRoot() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(#""response: {\"token\":\"secret\",\"userInfo\":{\"name\":\"Ada\"}}""#),
            #""response: {\"token\":\"[REDACTED]\",\"userInfo\":\"[REDACTED]\"}""#
        )
    }

    func testNativeLogSummaryRedactsRepeatedJSONStringRootEncoding() throws {
        var message = #"response: {"token":"secret"}"#
        var expected = #"response: {"token":"[REDACTED]"}"#
        for _ in 0..<3 {
            let messageData = try JSONSerialization.data(withJSONObject: message, options: [.fragmentsAllowed])
            let expectedData = try JSONSerialization.data(withJSONObject: expected, options: [.fragmentsAllowed])
            message = try XCTUnwrap(String(data: messageData, encoding: .utf8))
            expected = try XCTUnwrap(String(data: expectedData, encoding: .utf8))
        }

        XCTAssertEqual(BridgeNativeLog.sanitizedSummary(message), expected)
    }

    func testNativeLogSummaryPreservesFieldBoundariesWhenReplacingControlCharacters() {
        for separator in ["\n", "\r", "\t", "\u{0000}", "\u{001B}"] {
            XCTAssertEqual(
                BridgeNativeLog.sanitizedSummary("ready" + separator + "token=secret"),
                "ready token=[REDACTED]"
            )
        }
    }

    func testNativeLogSummaryPreservesControlBoundariesInsideJSONStrings() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(#"{"note":"ready\ntoken=secret"}"#),
            #"{"note":"ready token=[REDACTED]"}"#
        )
    }

    func testNativeLogSummaryRedactsCompleteDigestCredentialsToTheLineBoundary() {
        let message = "ready\nAuthorization: Digest username=\"Ada\", realm=\"private\", nonce=\"nonce-secret\", uri=\"/private\", response=\"response-secret\", qop=auth, nc=00000001, cnonce=\"client-secret\"\nversion 1.2.3 api.example.com"

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            "ready Authorization: [REDACTED] version 1.2.3 api.example.com"
        )
    }

    func testNativeLogSummaryRedactsDigestCredentialsWithControlSeparators() {
        for separator in ["\u{0000}", "\t", "\u{001B}"] {
            let message = "Authorization:" + separator + "Digest username=\"Ada\"," + separator
                + "realm=\"private\", nonce=\"nonce-secret\"\nversion 1.2.3 api.example.com"

            XCTAssertEqual(
                BridgeNativeLog.sanitizedSummary(message),
                "Authorization: [REDACTED] version 1.2.3 api.example.com"
            )
        }
    }

    func testNativeLogSummaryRedactsCompleteDigestCredentialsInsideJSONString() {
        let message = #"{"note":"authorization=digest username=\"Ada\", realm=\"private\", nonce=\"nonce-secret\", uri=\"/private\", response=\"response-secret\"","label":"1.2.3 api.example.com"}"#

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            #"{"label":"1.2.3 api.example.com","note":"authorization=[REDACTED]"}"#
        )
    }

    func testNativeLogSummaryRedactsEntireUserInfoWhenEmbeddedJSONContainsDigestCredentials() {
        let message = #"response: {"userInfo":{"name":"Ada","note":"Authorization: Digest username=\"U\", realm=\"private\""}}"#

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            #"response: {"userInfo":"[REDACTED]"}"#
        )
    }

    func testNativeLogSummaryPreservesEmbeddedJSONStructureWhenRedactingDigestCredentials() {
        let message = #"response: {"note":"Authorization: Digest username=\"U\", realm=\"private\"","label":"version 1.2.3 api.example.com"}"#

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            #"response: {"label":"version 1.2.3 api.example.com","note":"Authorization: [REDACTED]"}"#
        )
    }

    func testNativeLogSummaryRedactsNormalizedSensitiveFieldNames() {
        let message = "device_id=device-1 orderNo: order-2 payload=payload-3 accessToken: access-4 refreshToken=refresh-5"

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            "device_id=[REDACTED] orderNo: [REDACTED] payload=[REDACTED] accessToken: [REDACTED] refreshToken=[REDACTED]"
        )
    }

    func testNativeLogSummaryStripsURLUserInfo() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary("url=https://user:password@example.com/path"),
            "url=https://example.com/path"
        )
    }

    func testNativeLogSummaryRedactsDetachedJWSWithAnAlgorithmHeader() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary("proof eyJhbGciOiJub25lIn0..signature"),
            "proof [REDACTED]"
        )
    }

    func testNativeLogSummaryKeepsOrdinaryVersionsAndHostnames() {
        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary("version 1.2.3 host api.example.com"),
            "version 1.2.3 host api.example.com"
        )
    }

    func testNativeLogSummarySanitizesNonSensitiveJSONStringsWithoutChangingOrdinaryText() {
        let message = #"{"url":"https://user:password@example.com/path?token=secret","proof":"eyJhbGciOiJub25lIn0..signature","note":"Authorization: Basic credentials","label":"1.2.3 api.example.com"}"#

        XCTAssertEqual(
            BridgeNativeLog.sanitizedSummary(message),
            #"{"label":"1.2.3 api.example.com","note":"Authorization: [REDACTED]","proof":"[REDACTED]","url":"https://example.com/path"}"#
        )
    }
}
