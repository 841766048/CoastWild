import Foundation

public struct IntegrationEnvironment: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case development
        case release
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case invalidURL(String)
        case insecureURL(String)
        case missingValue(String)
        case testValue(String)
    }

    public let mode: Mode
    public let primaryHost: URL
    public let privacyURL: URL
    public let termsURL: URL
    public let appStoreID: String
    public let bundleIdentifier: String
    /// Backend identity is separate from the installed app and local device identity.
    public var integrationPackageIdentifier: String {
        mode == .development ? "test.duckegg.ios" : bundleIdentifier
    }

    public init(
        mode: Mode,
        primaryHost: String,
        privacyURL: String,
        termsURL: String,
        appStoreID: String,
        bundleIdentifier: String
    ) throws {
        self.mode = mode
        self.primaryHost = try Self.normalizedURL(primaryHost, field: "primaryHost")
        self.privacyURL = try Self.normalizedURL(privacyURL, field: "privacyURL")
        self.termsURL = try Self.normalizedURL(termsURL, field: "termsURL")
        self.appStoreID = appStoreID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func validateForRelease() throws {
        let urls: [(String, URL)] = [
            ("primaryHost", primaryHost),
            ("privacyURL", privacyURL),
            ("termsURL", termsURL),
        ]

        for (field, url) in urls {
            guard url.scheme?.lowercased() == "https" else {
                throw ValidationError.insecureURL(field)
            }
            if Self.isKnownTestHost(url.host) {
                throw ValidationError.testValue(field)
            }
        }

        guard !appStoreID.isEmpty else {
            throw ValidationError.missingValue("appStoreID")
        }
        guard !bundleIdentifier.isEmpty else {
            throw ValidationError.missingValue("bundleIdentifier")
        }
        if bundleIdentifier == "test.duckegg.ios" || bundleIdentifier.hasSuffix(".test") {
            throw ValidationError.testValue("bundleIdentifier")
        }
    }

    private static func normalizedURL(_ value: String, field: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              components.scheme != nil,
              components.host != nil
        else {
            throw ValidationError.invalidURL(field)
        }

        if components.path.count > 1 {
            while components.path.hasSuffix("/") {
                components.path.removeLast()
            }
        } else if components.path == "/" {
            components.path = ""
        }

        guard let url = components.url else {
            throw ValidationError.invalidURL(field)
        }
        return url
    }

    private static func isKnownTestHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return true }
        return host == "localhost"
            || host.hasSuffix(".localhost")
            || host == "test-app.bigegg.work"
            || host == "test-h5.bigegg.work"
            || host == "test-im.bigegg.work"
            || host == "test-log.bigegg.work"
            || host.hasSuffix(".test")
    }
}
