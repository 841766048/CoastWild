import Foundation

public enum TrackingAuthorizationStatus: String, CaseIterable, Sendable {
    case notDetermined, restricted, denied, authorized
}

public protocol TrackingAuthorizationProviding: Sendable {
    func requestAuthorization() async -> TrackingAuthorizationStatus
}

public protocol AttributionSDKProviding: Sendable {
    func start(appToken: String, authorization: TrackingAuthorizationStatus) async
}

public actor AttributionCoordinator {
    private let authorization: any TrackingAuthorizationProviding
    private let sdk: any AttributionSDKProviding
    private var started = false

    public init(authorization: any TrackingAuthorizationProviding, sdk: any AttributionSDKProviding) {
        self.authorization = authorization; self.sdk = sdk
    }

    public func start(privacyConsentGranted: Bool, appToken: String) async {
        guard privacyConsentGranted, !started else { return }
        let appToken = appToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appToken.isEmpty else { return }
        let status = await authorization.requestAuthorization()
        started = true
        await sdk.start(appToken: appToken, authorization: status)
    }

}
