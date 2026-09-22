import Foundation

public enum AttributionReportingError: Error, Equatable, Sendable {
    case missingSession
    case sessionMismatch
}

public actor IntegrationAttributionReporter: AttributionReporting {
    private let client: IntegrationAPIClient
    private let sessions: RemoteSessionStore
    private let package: String
    private let version: String
    private let deviceID: String

    public init(client: IntegrationAPIClient, sessions: RemoteSessionStore,
                package: String, version: String, deviceID: String) {
        self.client = client; self.sessions = sessions; self.package = package
        self.version = version; self.deviceID = deviceID
    }

    public func submit(_ snapshot: AttributionSnapshot, userID: String) async throws {
        guard let session = await sessions.session() else { throw AttributionReportingError.missingSession }
        guard session.userID == userID else { throw AttributionReportingError.sessionMismatch }
        _ = try await client.submitAttribution(.init(
            package: package,
            version: version,
            deviceID: deviceID,
            userID: userID,
            source: snapshot.source,
            adGroupID: snapshot.adGroupID,
            adSetID: snapshot.adSetID,
            campaignID: snapshot.campaignID,
            sdk: "AJ",
            sdkVersion: snapshot.sdkVersion
        ), session: session.requestSession)
    }
}
