import Foundation

public struct IntegrationRuntimeSnapshot: Equatable, Sendable {
    public let privacyURL: URL
    public let termsURL: URL
    public let appID: String
    public let adjustToken: String
    public let adjustPurchaseToken: String

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
        bundleIdentifier = environment.bundleIdentifier
        current = defaults
    }

    public func snapshot() -> IntegrationRuntimeSnapshot {
        current
    }

    public func apply(configuration: JSONValue) {
        guard let externalData = appExternalData(in: configuration) else {
            return
        }

        let prefix = bundleIdentifier + ":"
        current = IntegrationRuntimeSnapshot(
            privacyURL: httpsURL(externalData[prefix + "privacy"]) ?? defaults.privacyURL,
            termsURL: httpsURL(externalData[prefix + "terms"]) ?? defaults.termsURL,
            appID: nonemptyString(externalData[prefix + "app_id"]) ?? defaults.appID,
            adjustToken: nonemptyString(externalData[prefix + "aj_token"]) ?? defaults.adjustToken,
            adjustPurchaseToken: nonemptyString(externalData[prefix + "aj_purchase_token"])
                ?? defaults.adjustPurchaseToken
        )
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
