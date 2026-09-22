import Foundation

public struct BusinessWebBaseURLs: Equatable, Sendable {
    public let app: String
    public let im: String
    public let log: String
    public let privacy: String
    public let terms: String

    public init(app: String, im: String, log: String, privacy: String, terms: String) {
        self.app = app
        self.im = im
        self.log = log
        self.privacy = privacy
        self.terms = terms
    }
}

public struct BusinessWebPackageInfo: Equatable, Sendable {
    public let localeIdentifier: String
    public let appName: String
    public let packageName: String

    public init(localeIdentifier: String, appName: String, packageName: String) {
        self.localeIdentifier = localeIdentifier
        self.appName = appName
        self.packageName = packageName
    }
}

public struct BusinessWebSafeAreaInsets: Equatable, Sendable {
    public static let zero = Self(top: 0, bottom: 0, left: 0, right: 0)
    public let top: Int
    public let bottom: Int
    public let left: Int
    public let right: Int

    public init(top: Int, bottom: Int, left: Int, right: Int) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }
}

public struct BusinessWebBootstrap: Sendable {
    public let httpHeaders: [String: String]
    public let baseURLs: BusinessWebBaseURLs
    public let packageInfo: BusinessWebPackageInfo
    public let encryptedConfiguration: JSONValue
    public let strategy: JSONValue
    public let userInfo: JSONValue
    public let appID: String
    public let reportSubheading: String
    public let reportDescription: String

    public init(
        httpHeaders: [String: String],
        baseURLs: BusinessWebBaseURLs,
        packageInfo: BusinessWebPackageInfo,
        encryptedConfiguration: JSONValue,
        strategy: JSONValue,
        userInfo: JSONValue,
        appID: String,
        reportSubheading: String,
        reportDescription: String
    ) {
        self.httpHeaders = httpHeaders
        self.baseURLs = baseURLs
        self.packageInfo = packageInfo
        self.encryptedConfiguration = encryptedConfiguration
        self.strategy = strategy
        self.userInfo = userInfo
        self.appID = appID
        self.reportSubheading = reportSubheading
        self.reportDescription = reportDescription
    }

    public func javaScript(
        webLoadTimeMilliseconds: Int64,
        safeAreaInsets: BusinessWebSafeAreaInsets,
        appIconDataURL: String
    ) throws -> String {
        let options = try configurationValue().foundationObject
        let insets: [String: Any] = [
            "top": safeAreaInsets.top, "bottom": safeAreaInsets.bottom,
            "left": safeAreaInsets.left, "right": safeAreaInsets.right,
        ]
        return [
            "window.appConfigOptions=\(try json(options));",
            "window.webLoadTime=\(webLoadTimeMilliseconds);",
            "window.safeAreaInsets=\(try json(insets));",
            "window.appIconBase64=\(try json(appIconDataURL));",
        ].joined(separator: "\n")
    }

    /// The same payload is used for initial injection and a refreshed background-login callback.
    public func configurationValue() throws -> JSONValue {
        try JSONValue(any: [
            "http_headers": httpHeaders,
            "appBaseUrl": [
                "app": baseURLs.app, "im": baseURLs.im, "log": baseURLs.log,
                "privacyLink": baseURLs.privacy, "termsLink": baseURLs.terms,
            ],
            "appPackageInfo": [
                "lanId": packageInfo.localeIdentifier,
                "appName": packageInfo.appName,
                "packageName": packageInfo.packageName,
            ],
            "encConfigData": encryptedConfiguration.foundationObject,
            "strategyData": strategy.foundationObject,
            "nativeWebIndexHandled": "1",
            "userInfo": userInfo.foundationObject,
            "appId": appID,
            "reportSubheading": reportSubheading,
            "reportDescription": reportDescription,
            "takeOverThirdPayWeb": "1",
            "takeOverFilePreviewWeb": "1",
            "takeOverBannerWeb": "0",
            "supportGetLocalPrice": "1",
        ])
    }

    public func withLanguage(_ language: String) -> BusinessWebBootstrap {
        let normalized = BridgeLanguage.normalized(language)
        var headers = httpHeaders
        headers["lang"] = normalized
        return BusinessWebBootstrap(
            httpHeaders: headers, baseURLs: baseURLs,
            packageInfo: .init(localeIdentifier: normalized, appName: packageInfo.appName,
                               packageName: packageInfo.packageName),
            encryptedConfiguration: encryptedConfiguration, strategy: strategy, userInfo: userInfo,
            appID: appID, reportSubheading: reportSubheading, reportDescription: reportDescription)
    }

    private func json(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])
        guard let value = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return value
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
