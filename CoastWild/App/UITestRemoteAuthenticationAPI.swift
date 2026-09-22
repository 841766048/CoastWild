import Foundation

actor UITestRemoteAuthenticationAPI: RemoteAuthenticationAPI {
  func getConfig(session: RequestSession) async throws -> IntegrationConfigBundle {
    IntegrationConfigBundle(k2: "", k3: "", k4: "", configuration: .object([:]))
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
