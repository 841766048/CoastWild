import Foundation

actor UITestRemoteAuthenticationAPI: RemoteAuthenticationAPI {
  func getConfig(session: RequestSession) async throws -> IntegrationConfigBundle {
    if ProcessInfo.processInfo.arguments.contains("--ui-testing-slow-recovery") {
      try await Task.sleep(nanoseconds: 2_000_000_000)
    }
    return IntegrationConfigBundle(k2: "", k3: "", k4: "", configuration: .object([:]))
  }

  func oauth(_ request: OAuthRequest, session: RequestSession) async throws -> JSONValue {
    try JSONValue(any: [
      "token": "ui-test-session-token",
      "userInfo": ["userId": "ui-test-remote-user"],
      "isFirstRegister": 0,
    ])
  }

  func getStrategy(session: RequestSession) async throws -> JSONValue {
    .object(["isReviewPkg": .bool(true)])
  }
}
