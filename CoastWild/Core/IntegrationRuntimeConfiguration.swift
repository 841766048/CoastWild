import Foundation

public struct IntegrationRuntimeSnapshot: Equatable, Sendable {
    public let privacyURL: URL
    public let termsURL: URL
    public let appID: String
    public let adjustToken: String
    public let adjustPurchaseToken: String
    public internal(set) var riskAreaCode: String?
    public internal(set) var attributionSDK: String = "AJ"
    public internal(set) var facebookAppID: String?
    public internal(set) var facebookClientToken: String?
    public internal(set) var riskFactor: String?
    public internal(set) var webIndexURL: URL?
    public internal(set) var encryptedConfiguration: JSONValue = .null
    public internal(set) var configuration: JSONValue = .null
    public internal(set) var strategy: JSONValue = .null

    public func headers(base: [String: String]) -> [String: String] {
        var headers = base
        headers["rc_type"] = riskAreaCode
        headers["attribution_sdk"] = attributionSDK
        if attributionSDK == "AF" { headers["attribution_sdk_ver"] = "0.0.0" }
        return headers
    }

    public init(environment: IntegrationEnvironment) {
        privacyURL = environment.privacyURL
        termsURL = environment.termsURL
        appID = environment.appStoreID
        adjustToken = environment.adjustToken
        adjustPurchaseToken = environment.adjustPurchaseToken
    }

    init(
        privacyURL: URL,
        termsURL: URL,
        appID: String,
        adjustToken: String,
        adjustPurchaseToken: String
    ) {
        self.privacyURL = privacyURL
        self.termsURL = termsURL
        self.appID = appID
        self.adjustToken = adjustToken
        self.adjustPurchaseToken = adjustPurchaseToken
    }
}

public actor IntegrationRuntimeConfiguration {
    private let defaults: IntegrationRuntimeSnapshot
    private let bundleIdentifier: String
    private var current: IntegrationRuntimeSnapshot

    public init(environment: IntegrationEnvironment) {
        let defaults = IntegrationRuntimeSnapshot(environment: environment)
        self.defaults = defaults
        bundleIdentifier = environment.integrationPackageIdentifier
        current = defaults
    }

    public func snapshot() -> IntegrationRuntimeSnapshot {
        current
    }

    public func reset() { current = defaults }

    public func apply(strategy: JSONValue) { current.strategy = strategy }

    public func apply(configuration: JSONValue, encryptedConfiguration: JSONValue = .null) {
        let externalData = appExternalData(in: configuration) ?? [:]

        let prefix = bundleIdentifier + ":"
        current = IntegrationRuntimeSnapshot(
            privacyURL: httpsURL(externalData[prefix + "privacy"]) ?? defaults.privacyURL,
            termsURL: httpsURL(externalData[prefix + "terms"]) ?? defaults.termsURL,
            appID: nonemptyString(externalData[prefix + "app_id"]) ?? defaults.appID,
            adjustToken: nonemptyString(externalData[prefix + "aj_token"]) ?? defaults.adjustToken,
            adjustPurchaseToken: nonemptyString(externalData[prefix + "aj_purchase_token"])
                ?? defaults.adjustPurchaseToken
        )
        current.configuration = configuration
        current.encryptedConfiguration = encryptedConfiguration
        // Missing items reset to bundled values while retaining the original payload.
        if case .array? = configuration["items"] {
            current.riskAreaCode = nonemptyString(item("rc_area_code", in: configuration))
            current.facebookAppID = nonemptyString(item("app_fb_id", in: configuration))
            current.facebookClientToken = nonemptyString(item("app_fb_client_token", in: configuration))
            current.attributionSDK = nonemptyString(item("attribution_sdk", in: configuration)) == "AF" ? "AF" : "AJ"
        }
        current.riskFactor = configuration["riskControlInfoConfig"]?["k_factor"]?.stringValue
        current.webIndexURL = httpsURL(externalData["webIndexUrl"])
    }

    private func item(_ name: String, in configuration: JSONValue) -> JSONValue? {
        guard case let .array(items)? = configuration["items"] else { return nil }
        return items.first { $0["name"]?.stringValue == name }?["data"]
    }

    private func appExternalData(in configuration: JSONValue) -> [String: JSONValue]? {
        guard case let .object(root) = configuration,
              case let .array(items)? = root["items"]
        else {
            return nil
        }

        for item in items {
            guard case let .object(fields) = item,
                  fields["name"]?.stringValue == "app_ext_data",
                  case let .object(data)? = fields["data"]
            else {
                continue
            }
            return data
        }
        return nil
    }

    private func nonemptyString(_ value: JSONValue?) -> String? {
        guard let trimmed = value?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    private func httpsURL(_ value: JSONValue?) -> URL? {
        guard let string = nonemptyString(value),
              let components = URLComponents(string: string),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              let url = components.url
        else {
            return nil
        }
        return url
    }
}
