import Foundation

public struct RequestSession: Equatable, Sendable {
    public static let anonymous = RequestSession(token: "", userID: "")

    public let token: String
    public let userID: String

    public init(token: String, userID: String) {
        self.token = token
        self.userID = userID
    }
}

public struct RequestContextValues: Equatable, Sendable {
    public let deviceID: String
    public let model: String
    public let language: String
    public let appVersion: String
    public let bundleIdentifier: String
    public let timeZone: String
    public let country: String
    public let platformVersion: String
    public let localeIdentifier: String
    public let riskAreaCode: String?

    public init(
        deviceID: String,
        model: String,
        language: String,
        appVersion: String,
        bundleIdentifier: String,
        timeZone: String,
        country: String,
        platformVersion: String,
        localeIdentifier: String,
        riskAreaCode: String? = nil
    ) {
        self.deviceID = deviceID
        self.model = model
        self.language = language
        self.appVersion = appVersion
        self.bundleIdentifier = bundleIdentifier
        self.timeZone = timeZone
        self.country = country
        self.platformVersion = platformVersion
        self.localeIdentifier = localeIdentifier
        self.riskAreaCode = riskAreaCode
    }
}

public protocol RequestContextProviding: Sendable {
    func headers(session: RequestSession) -> [String: String]
    func riskParameters(session: RequestSession) -> [String: String]
}

public struct RequestContextProvider: RequestContextProviding {
    public let values: RequestContextValues

    public init(values: RequestContextValues) {
        self.values = values
    }

    public func headers(session: RequestSession) -> [String: String] {
        var headers = [
            "device-id": values.deviceID,
            "model": values.model,
            "lang": values.language,
            "sys_lan": values.language,
            "Authorization": "Bearer \(session.token)",
            "is_anchor": "false",
            "platform": "iOS",
            "ver": values.appVersion,
            "pkg": values.bundleIdentifier,
            "time_zone": values.timeZone,
            "device_lang": values.language,
            "device_country": values.country,
            "platform_ver": values.platformVersion,
            "system_language": values.localeIdentifier,
            "user_id": session.userID,
            "sec_ver": "0",
        ]
        if let riskAreaCode = values.riskAreaCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !riskAreaCode.isEmpty {
            headers["rc_type"] = riskAreaCode
        }
        return headers
    }

    public func riskParameters(session: RequestSession) -> [String: String] {
        [
            "platform": "iOS",
            "pkg": values.bundleIdentifier,
            "ver": values.appVersion,
            "platform_ver": values.platformVersion,
            "model": values.model,
            "user_id": session.userID,
            "device_id": values.deviceID,
            "system_language": values.localeIdentifier,
            "time_zone": values.timeZone,
        ]
    }
}
