import CoreFoundation
import Foundation

public enum JSONValue: Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public subscript(key: String) -> JSONValue? {
        guard case let .object(object) = self else { return nil }
        return object[key]
    }

    init(any value: Any) throws {
        switch value {
        case let value as [String: Any]:
            self = .object(try value.mapValues(JSONValue.init(any:)))
        case let value as [Any]:
            self = .array(try value.map(JSONValue.init(any:)))
        case let value as String:
            self = .string(value)
        case let value as NSNumber where CFGetTypeID(value) == CFBooleanGetTypeID():
            self = .bool(value.boolValue)
        case let value as NSNumber:
            self = .number(value.doubleValue)
        case _ as NSNull:
            self = .null
        default:
            throw IntegrationAPIError.invalidEnvelope
        }
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
}

public struct IntegrationConfigBundle: Equatable, Sendable {
    public let k2: String
    public let k3: String
    public let k4: String
    public let configuration: JSONValue

    public init(k2: String, k3: String, k4: String, configuration: JSONValue) {
        self.k2 = k2
        self.k3 = k3
        self.k4 = k4
        self.configuration = configuration
    }
}

public struct OAuthRequest: Equatable, Sendable {
    public let token: String
    public let relogin: Bool
    public let riskInfo: String?

    public init(token: String, relogin: Bool, riskInfo: String? = nil) {
        self.token = token
        self.relogin = relogin
        self.riskInfo = riskInfo
    }

    var parameters: [String: Any] {
        var value: [String: Any] = [
            "token": token,
            "oauthType": "4",
            "relogin": relogin ? "1" : "0",
        ]
        if let riskInfo, !riskInfo.isEmpty {
            value["info"] = riskInfo
        }
        return value
    }
}

public struct AttributionRequest: Equatable, Sendable {
    public let package: String
    public let version: String
    public let deviceID: String
    public let userID: String
    public let source: String
    public let adGroupID: String
    public let adSetID: String
    public let campaignID: String
    public let sdk: String
    public let sdkVersion: String

    public init(
        package: String,
        version: String,
        deviceID: String,
        userID: String,
        source: String,
        adGroupID: String,
        adSetID: String,
        campaignID: String,
        sdk: String,
        sdkVersion: String
    ) {
        self.package = package
        self.version = version
        self.deviceID = deviceID
        self.userID = userID
        self.source = source
        self.adGroupID = adGroupID
        self.adSetID = adSetID
        self.campaignID = campaignID
        self.sdk = sdk
        self.sdkVersion = sdkVersion
    }

    var parameters: [String: Any] {
        [
            "pkg": package,
            "ver": version,
            "device-id": deviceID,
            "userId": userID,
            "utmSource": source,
            "adgroupId": adGroupID,
            "adsetId": adSetID,
            "campaignId": campaignID,
            "attributionSdk": sdk,
            "attributionSdkVer": sdkVersion,
            "adset": "",
            "afStatus": "",
            "agency": "",
            "afChannel": "",
            "campaign": "",
        ]
    }
}
