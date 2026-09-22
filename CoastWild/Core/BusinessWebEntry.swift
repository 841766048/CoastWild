import Foundation

/// Resolves the documented URL priority without using reviewer identity.
public enum BusinessWebEntry {
    public enum EntryError: Error { case invalidURL, untrustedOrigin }

    public static func restrictScript(_ script: String, to url: URL) throws -> String {
        guard var origin = URLComponents(url: url, resolvingAgainstBaseURL: false),
              origin.scheme == "https", origin.host != nil else { throw EntryError.invalidURL }
        origin.path = ""; origin.query = nil; origin.fragment = nil
        origin.user = nil; origin.password = nil
        if origin.port == 443 { origin.port = nil }
        let encoded = try JSONSerialization.data(withJSONObject: origin.string!, options: [.fragmentsAllowed])
        return "if (window.location.origin === \(String(decoding: encoded, as: UTF8.self))) {\n\(script)\n}"
    }

    public static func url(bundled: URL, configured: URL?, strategy: JSONValue,
                           timestamp: Int64) throws -> URL {
        var selected = configured ?? bundled
        if let segment = try optionalURLString(strategy["data"]?["webIndexUrl2"]) {
            guard segment != ".", segment != "..",
                  segment.unicodeScalars.allSatisfy({
                      CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.").contains($0)
                  }),
                  var components = URLComponents(url: selected, resolvingAgainstBaseURL: false)
            else { throw EntryError.invalidURL }
            let parent = (components.path as NSString).deletingLastPathComponent
            components.path = (parent.hasSuffix("/") ? parent : parent + "/") + segment
            guard let next = components.url else { throw EntryError.invalidURL }
            selected = next
        } else if let value = try optionalURLString(strategy["data"]?["webIndexUrl"]) {
            guard let next = URL(string: value) else {
                throw EntryError.invalidURL
            }
            selected = next
        }
        guard var components = URLComponents(url: selected, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https", components.user == nil, components.password == nil
        else { throw EntryError.invalidURL }
        // A server-supplied URL must not silently expand the credential-injection trust boundary.
        guard components.host?.lowercased() == bundled.host?.lowercased(),
              (components.port ?? 443) == (bundled.port ?? 443)
        else { throw EntryError.untrustedOrigin }
        var query = components.queryItems ?? []
        query.removeAll { $0.name == "t" }
        query.append(URLQueryItem(name: "t", value: String(timestamp)))
        components.queryItems = query
        guard let result = components.url else { throw EntryError.invalidURL }
        return result
    }

    private static func optionalURLString(_ value: JSONValue?) throws -> String? {
        guard let value, value != .null else { return nil }
        guard let string = value.stringValue else { throw EntryError.invalidURL }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func bootstrap(environment: IntegrationEnvironment, runtime: IntegrationRuntimeSnapshot,
                                 session: RemoteSession, strategy: JSONValue,
                                 headers: [String: String], package: BusinessWebPackageInfo) throws -> BusinessWebBootstrap {
        let response = try JSONValue(any: JSONSerialization.jsonObject(with: session.responseData))
        guard let userInfo = response["userInfo"] else { throw RemoteSessionError.invalidOAuthResponse }
        return BusinessWebBootstrap(
            httpHeaders: headers,
            baseURLs: .init(app: environment.primaryHost.absoluteString, im: environment.imHost.absoluteString,
                            log: environment.logHost.absoluteString, privacy: runtime.privacyURL.absoluteString,
                            terms: runtime.termsURL.absoluteString),
            packageInfo: package, encryptedConfiguration: runtime.encryptedConfiguration,
            strategy: strategy, userInfo: userInfo, appID: runtime.appID,
            reportSubheading: environment.reportSubheading, reportDescription: environment.reportDescription)
    }
}
