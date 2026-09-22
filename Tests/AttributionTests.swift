import XCTest
@testable import CoastWildCore

final class AttributionTests: XCTestCase {
    func testPrivacyConsentIsRequiredBeforeATTAndSDKStartup() async {
        let events = AttributionEvents()
        let coordinator = AttributionCoordinator(
            authorization: AuthorizationFake(status: .authorized, events: events),
            sdk: AttributionSDKFake(events: events),
            clock: { Date(timeIntervalSince1970: 100) }
        )
        await coordinator.start(privacyConsentGranted: false, appToken: "app-token", purchaseToken: "purchase-token")
        let values = await events.values
        XCTAssertEqual(values, [])
    }

    func testAllATTResultsRequestBeforeSDKStartup() async {
        for status in TrackingAuthorizationStatus.allCases {
            let events = AttributionEvents()
            let coordinator = AttributionCoordinator(
                authorization: AuthorizationFake(status: status, events: events),
                sdk: AttributionSDKFake(events: events),
                clock: { Date(timeIntervalSince1970: 100) }
            )
            await coordinator.start(privacyConsentGranted: true, appToken: "app-token", purchaseToken: "purchase-token")
            let values = await events.values
            XCTAssertEqual(values, ["request-att", "start:\(status.rawValue):app-token"])
        }
    }

    func testBlankTokenNeverStartsSDK() async {
        let events = AttributionEvents()
        let coordinator = AttributionCoordinator(
            authorization: AuthorizationFake(status: .authorized, events: events),
            sdk: AttributionSDKFake(events: events),
            clock: { Date() }
        )
        await coordinator.start(privacyConsentGranted: true, appToken: " ", purchaseToken: "purchase")
        let values = await events.values
        XCTAssertEqual(values, [])
    }

    func testPurchaseUsesConfiguredTokenAndSuppressesImmediateDuplicate() async {
        let events = AttributionEvents()
        let clock = MutableAttributionClock(Date(timeIntervalSince1970: 100))
        let coordinator = AttributionCoordinator(
            authorization: AuthorizationFake(status: .denied, events: events),
            sdk: AttributionSDKFake(events: events),
            clock: { clock.value }
        )
        await coordinator.start(privacyConsentGranted: true, appToken: "app-token", purchaseToken: "purchase-token")
        await coordinator.trackPurchase(amount: 4.99, currency: "USD")
        await coordinator.trackPurchase(amount: 4.99, currency: "USD")
        clock.value = Date(timeIntervalSince1970: 104)
        await coordinator.trackPurchase(amount: 4.99, currency: "USD")
        let values = await events.values
        XCTAssertEqual(values, [
            "request-att", "start:denied:app-token",
            "purchase:purchase-token:4.99:USD", "purchase:purchase-token:4.99:USD"
        ])
    }

    func testPurchaseBeforeStartupOrWithInvalidValuesIsIgnored() async {
        let events = AttributionEvents()
        let coordinator = AttributionCoordinator(
            authorization: AuthorizationFake(status: .authorized, events: events),
            sdk: AttributionSDKFake(events: events),
            clock: { Date() }
        )
        await coordinator.trackPurchase(amount: 1, currency: "USD")
        await coordinator.start(privacyConsentGranted: true, appToken: "app-token", purchaseToken: "")
        await coordinator.trackPurchase(amount: -1, currency: "USD")
        await coordinator.trackPurchase(amount: 1, currency: "usd")
        let values = await events.values
        XCTAssertEqual(values, ["request-att", "start:authorized:app-token"])
    }
}

private actor AttributionEvents {
    private(set) var values: [String] = []
    func append(_ value: String) { values.append(value) }
}

private final class MutableAttributionClock: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Date
    init(_ value: Date) { stored = value }
    var value: Date {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}

private struct AuthorizationFake: TrackingAuthorizationProviding {
    let status: TrackingAuthorizationStatus
    let events: AttributionEvents
    func requestAuthorization() async -> TrackingAuthorizationStatus {
        await events.append("request-att")
        return status
    }
}

private struct AttributionSDKFake: AttributionSDKProviding {
    let events: AttributionEvents
    func start(appToken: String, authorization: TrackingAuthorizationStatus) async {
        await events.append("start:\(authorization.rawValue):\(appToken)")
    }
    func trackPurchase(eventToken: String, amount: Double, currency: String) async {
        await events.append("purchase:\(eventToken):\(amount):\(currency)")
    }
}
