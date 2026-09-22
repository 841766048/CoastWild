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

final class AdjustAttributionAdapter: AttributionSDKProviding, @unchecked Sendable {
  private let environment: String
  init(isProduction: Bool) {
    environment = isProduction ? ADJEnvironmentProduction : ADJEnvironmentSandbox
  }

  func start(appToken: String, authorization: TrackingAuthorizationStatus) async {
    await MainActor.run {
      guard let configuration = ADJConfig(appToken: appToken, environment: environment) else { return }
      if authorization != .authorized { configuration.disableIdfaReading() }
      Adjust.initSdk(configuration)
    }
  }

  func trackPurchase(eventToken: String, amount: Double, currency: String) async {
    await MainActor.run {
      guard let event = ADJEvent(eventToken: eventToken) else { return }
      event.setRevenue(amount, currency: currency)
      Adjust.trackEvent(event)
    }
  }
}
