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
        let key = "LEGAL_\(rawValue.uppercased())_URL_EN"
        guard let value = configuration[key], let url = URL(string: value),
              url.scheme?.lowercased() == "https", url.host?.isEmpty == false
        else { return nil }
        return url
    }
}
