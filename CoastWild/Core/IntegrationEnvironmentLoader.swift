import Foundation

public enum IntegrationEnvironmentLoader {
    public enum LoadError: Error, Equatable, Sendable {
        case missingKey(String)
        case invalidMode(String)
    }

    public static func load(
        info: [String: Any],
        bundleIdentifier: String
    ) throws -> IntegrationEnvironment {
        let modeValue = try string("CoastIntegrationMode", in: info).lowercased()
        let mode: IntegrationEnvironment.Mode
        switch modeValue {
        case "development": mode = .development
        case "release": mode = .release
        default: throw LoadError.invalidMode(modeValue)
        }

        return try IntegrationEnvironment(
            mode: mode,
            primaryHost: string("CoastPrimaryHost", in: info),
            webHost: string("CoastWebHost", in: info),
            imHost: string("CoastIMHost", in: info),
            logHost: string("CoastLogHost", in: info),
            privacyURL: string("CoastPrivacyURL", in: info),
            termsURL: string("CoastTermsURL", in: info),
            appStoreID: string("CoastAppStoreID", in: info),
            bundleIdentifier: bundleIdentifier
        )
    }

    private static func string(_ key: String, in info: [String: Any]) throws -> String {
        guard let value = info[key] as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw LoadError.missingKey(key)
        }
        return value
    }
}
