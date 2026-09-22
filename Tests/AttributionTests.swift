import XCTest
@testable import CoastWildCore

final class AttributionTests: XCTestCase {
    func testAttributionCallbackIsPersistedAndSubmittedOnlyOncePerUser() async throws {
        let defaults = UserDefaults(suiteName: "AttributionTests.callback")!
        defaults.removePersistentDomain(forName: "AttributionTests.callback")
        let snapshot = AttributionSnapshot(source: "network", adGroupID: "group", adSetID: "creative", campaignID: "campaign", sdkVersion: "5.8.0")
        let reporter = AttributionReporterFake()
        let coordinator = AttributionSubmissionCoordinator(
            provider: AttributionProviderFake(snapshot: snapshot),
            store: AttributionSnapshotStore(defaults: defaults),
            reporter: reporter
        )
        try await coordinator.submitOnce(userID: "user-1")
        try await coordinator.submitOnce(userID: "user-1")
        let submissions = await reporter.submissions
        XCTAssertEqual(submissions, [.init(userID: "user-1", snapshot: snapshot)])
        XCTAssertEqual(AttributionSnapshotStore(defaults: defaults).snapshot(), snapshot)
    }

    func testThirtySecondFallbackSubmitsEmptySnapshotWhenCallbackNeverArrives() async throws {
        let defaults = UserDefaults(suiteName: "AttributionTests.fallback")!
        defaults.removePersistentDomain(forName: "AttributionTests.fallback")
        let reporter = AttributionReporterFake()
        let fallback = FallbackRecorder()
        let coordinator = AttributionSubmissionCoordinator(
            provider: AttributionProviderFake(snapshot: nil, neverReturns: true),
            store: AttributionSnapshotStore(defaults: defaults),
            reporter: reporter,
            fallback: { await fallback.run() }
        )
        try await coordinator.submitOnce(userID: "user-2")
        let fallbackCount = await fallback.count
        XCTAssertEqual(fallbackCount, 1)
        let submissions = await reporter.submissions
        XCTAssertEqual(submissions, [.init(userID: "user-2", snapshot: .empty(sdkVersion: "5.8.0"))])
    }

    func testFailedSubmissionRemainsPendingAndRetriesOnNextCall() async throws {
        let defaults = UserDefaults(suiteName: "AttributionTests.retry")!
        defaults.removePersistentDomain(forName: "AttributionTests.retry")
        let snapshot = AttributionSnapshot(source: "source", adGroupID: "", adSetID: "", campaignID: "campaign", sdkVersion: "5.8.0")
        let reporter = AttributionReporterFake(failuresRemaining: 1)
        let coordinator = AttributionSubmissionCoordinator(
            provider: AttributionProviderFake(snapshot: snapshot),
            store: AttributionSnapshotStore(defaults: defaults),
            reporter: reporter
        )
        do { try await coordinator.submitOnce(userID: "user-3"); XCTFail("Expected first submission failure") } catch {}
        try await coordinator.submitOnce(userID: "user-3")
        let attemptCount = await reporter.attemptCount
        XCTAssertEqual(attemptCount, 2)
    }

    func testSnapshotSanitizesControlCharactersAndLimitsFieldLength() {
        let snapshot = AttributionSnapshot(source: "  net\nwork  ", adGroupID: String(repeating: "x", count: 400), adSetID: "set\u{0000}", campaignID: " campaign ", sdkVersion: "5.8.0")
        XCTAssertEqual(snapshot.source, "network")
        XCTAssertEqual(snapshot.adGroupID.count, 256)
        XCTAssertEqual(snapshot.adSetID, "set")
        XCTAssertEqual(snapshot.campaignID, "campaign")
    }

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

private struct AttributionSubmission: Equatable, Sendable { let userID: String; let snapshot: AttributionSnapshot }
private enum AttributionReporterError: Error { case failed }
private actor AttributionReporterFake: AttributionReporting {
    private var failuresRemaining: Int
    private(set) var submissions: [AttributionSubmission] = []
    private(set) var attemptCount = 0
    init(failuresRemaining: Int = 0) { self.failuresRemaining = failuresRemaining }
    func submit(_ snapshot: AttributionSnapshot, userID: String) async throws {
        attemptCount += 1
        if failuresRemaining > 0 { failuresRemaining -= 1; throw AttributionReporterError.failed }
        submissions.append(.init(userID: userID, snapshot: snapshot))
    }
}

private actor AttributionProviderFake: AttributionSnapshotProviding {
    let snapshot: AttributionSnapshot?
    let neverReturns: Bool
    init(snapshot: AttributionSnapshot?, neverReturns: Bool = false) { self.snapshot = snapshot; self.neverReturns = neverReturns }
    func nextAttribution() async -> AttributionSnapshot? {
        if neverReturns { try? await Task.sleep(nanoseconds: 60_000_000_000) }
        return snapshot
    }
}

private actor FallbackRecorder {
    private(set) var count = 0
    func run() { count += 1 }
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
