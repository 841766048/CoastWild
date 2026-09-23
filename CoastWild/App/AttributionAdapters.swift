import AppTrackingTransparency
import AdjustSdk
import Foundation

struct SystemTrackingAuthorizationAdapter: TrackingAuthorizationProviding {
  func requestAuthorization() async -> TrackingAuthorizationStatus {
    let status = await ATTrackingManager.requestTrackingAuthorization()
    switch status {
    case .notDetermined: return .notDetermined
    case .restricted: return .restricted
    case .denied: return .denied
    case .authorized: return .authorized
    @unknown default: return .denied
    }
  }
}

final class AdjustAttributionAdapter: NSObject, AttributionSDKProviding, AttributionSnapshotProviding, AdjustDelegate, @unchecked Sendable {
  private let environment: String
  private let stream: AsyncStream<AttributionSnapshot>
  private let continuation: AsyncStream<AttributionSnapshot>.Continuation
  init(isProduction: Bool) {
    environment = isProduction ? ADJEnvironmentProduction : ADJEnvironmentSandbox
    var captured: AsyncStream<AttributionSnapshot>.Continuation!
    stream = AsyncStream { captured = $0 }
    continuation = captured
    super.init()
  }

  func start(appToken: String, authorization: TrackingAuthorizationStatus) async {
    await MainActor.run {
      guard let configuration = ADJConfig(appToken: appToken, environment: environment) else { return }
      if authorization != .authorized { configuration.disableIdfaReading() }
      configuration.delegate = self
      Adjust.initSdk(configuration)
    }
  }

  func nextAttribution() async -> AttributionSnapshot? {
    for await snapshot in stream { return snapshot }
    return nil
  }

  func adjustAttributionChanged(_ attribution: ADJAttribution?) {
    guard let attribution else { return }
    continuation.yield(.init(
      source: attribution.network ?? attribution.trackerName ?? "",
      adGroupID: attribution.adgroup ?? "",
      adSetID: attribution.creative ?? "",
      campaignID: attribution.campaign ?? "",
      sdkVersion: "5.8.0"
    ))
  }
}
