import Foundation

public enum TrackingAuthorizationStatus: String, CaseIterable, Sendable {
    case notDetermined, restricted, denied, authorized
}

public protocol TrackingAuthorizationProviding: Sendable {
    func requestAuthorization() async -> TrackingAuthorizationStatus
}

public protocol AttributionSDKProviding: Sendable {
    func start(appToken: String, authorization: TrackingAuthorizationStatus) async
    func trackPurchase(eventToken: String, amount: Double, currency: String) async
}

public actor AttributionCoordinator {
    public typealias Clock = @Sendable () -> Date
    private let authorization: any TrackingAuthorizationProviding
    private let sdk: any AttributionSDKProviding
    private let clock: Clock
    private var purchaseToken = ""
    private var started = false
    private var lastPurchase: (fingerprint: String, date: Date)?

    public init(authorization: any TrackingAuthorizationProviding, sdk: any AttributionSDKProviding,
                clock: @escaping Clock = { Date() }) {
        self.authorization = authorization; self.sdk = sdk; self.clock = clock
    }

    public func start(privacyConsentGranted: Bool, appToken: String, purchaseToken: String) async {
        guard privacyConsentGranted, !started else { return }
        let appToken = appToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appToken.isEmpty else { return }
        let status = await authorization.requestAuthorization()
        self.purchaseToken = purchaseToken.trimmingCharacters(in: .whitespacesAndNewlines)
        started = true
        await sdk.start(appToken: appToken, authorization: status)
    }

    public func trackPurchase(amount: Double, currency: String) async {
        guard started, !purchaseToken.isEmpty, amount.isFinite, amount > 0,
              currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil else { return }
        let now = clock(); let fingerprint = "\(amount)|\(currency)"
        if let lastPurchase, lastPurchase.fingerprint == fingerprint,
           now.timeIntervalSince(lastPurchase.date) < 3 { return }
        lastPurchase = (fingerprint, now)
        await sdk.trackPurchase(eventToken: purchaseToken, amount: amount, currency: currency)
    }
}
