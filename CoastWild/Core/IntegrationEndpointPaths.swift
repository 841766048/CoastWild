public struct IntegrationEndpointPaths: Equatable, Sendable {
    public let getConfig: String
    public let oauth: String

    public static let `default` = IntegrationEndpointPaths(
        getConfig: "/config/getAppConfigPostV2",
        oauth: "/security/oauth"
    )
}
