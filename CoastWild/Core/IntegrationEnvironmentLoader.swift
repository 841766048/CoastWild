import Foundation

public enum IntegrationEnvironmentLoader {
    public enum LoadError: Error, Equatable, Sendable {
        case missingKey(String)
        case invalidMode(String)
        case invalidPropertyList
    }

    public static func load(
        propertyListData: Data,
        bundleIdentifier: String
    ) throws -> IntegrationEnvironment {
        guard let info = try? PropertyListSerialization.propertyList(
            from: propertyListData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw LoadError.invalidPropertyList
        }
        return try load(info: info, bundleIdentifier: bundleIdentifier)
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
            bundleIdentifier: bundleIdentifier,
            adjustToken: string("CoastAdjustToken", in: info),
            reportSubheading: string("CoastReportSubheading", in: info),
            reportDescription: string("CoastReportDescription", in: info),
            smallIconName: string("CoastSmallIconName", in: info),
            launchImageName: string("CoastLaunchImageName", in: info)
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
