import Foundation

enum LegalDocument: String, CaseIterable {
    case privacy
    case terms

    func title(language: String) -> String {
        let chinese = language.hasPrefix("zh")
        switch self {
        case .privacy: return chinese ? "隐私政策" : "Privacy Policy"
        case .terms: return chinese ? "用户协议" : "Terms of Use"
        }
    }

    func localResource(language: String) -> String {
        "Legal/\(rawValue)-\(language.hasPrefix("zh") ? "zh-Hans" : "en")"
    }

    func remoteURL(language: String, configuration: [String: String]) -> URL? {
        let languageKey = language.hasPrefix("zh") ? "ZH_HANS" : "EN"
        let key = "LEGAL_\(rawValue.uppercased())_URL_\(languageKey)"
        guard let value = configuration[key], let url = URL(string: value),
              url.scheme?.lowercased() == "https", url.host?.isEmpty == false
        else { return nil }
        return url
    }
}
