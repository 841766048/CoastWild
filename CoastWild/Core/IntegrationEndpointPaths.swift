public struct IntegrationEndpointPaths: Equatable, Sendable {
    public let getConfig: String
    public let getStrategy: String
    public let oauth: String
    public let createRecharge: String
    public let paymentRecharge: String
    public let ascribeRecord: String

    public static let `default` = IntegrationEndpointPaths(
        getConfig: "/config/getAppConfigPostV2",
        getStrategy: "/config/getStrategyPostV2",
        oauth: "/security/oauth",
        createRecharge: "/coin/recharge/create",
        paymentRecharge: "/coin/recharge/payment/ipa",
        ascribeRecord: "/hit/ascribeRecordReqs"
    )
}
