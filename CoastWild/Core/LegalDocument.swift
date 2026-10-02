import Foundation

enum LegalDocument: String, CaseIterable {
    case privacy
    case terms

    func title(language: String) -> String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms: return "Terms of Use"
        }
    }

    func localResource(language: String) -> String {
        "Legal/\(rawValue)-en"
    }

    func remoteURL(language: String, configuration: [String: String]) -> URL? {
        guard self == .privacy else { return nil }
        let key = "CoastPrivacyURL"
        guard let value = configuration[key], let url = URL(string: value),
              url.scheme?.lowercased() == "https", url.host?.isEmpty == false
        else { return nil }
        // Google's read-only HTML view renders without enabling page JavaScript.
        if url.host == "docs.google.com", url.path.hasSuffix("/edit"),
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.path = String(components.path.dropLast(5)) + "/mobilebasic"
            components.query = nil
            components.fragment = nil
            return components.url
        }
        return url
    }

    static var bundledConfiguration: [String: String] {
        guard let url = Bundle.main.url(forResource: "IntegrationConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let values = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String]
        else { return [:] }
        return values
    }
}
