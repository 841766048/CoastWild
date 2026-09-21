import Foundation

public enum BusinessWebNavigationDecision: Equatable, Sendable {
    case allow
    case openExternal(URL)
    case deny
}

public struct BusinessWebNavigationPolicy: Equatable, Sendable {
    private let allowedHosts: Set<String>
    private let externalSchemes: Set<String> = ["tel", "mailto", "itms-apps"]

    public init(allowedHosts: Set<String>) {
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
    }

    public func decision(for url: URL?) -> BusinessWebNavigationDecision {
        guard let url, let scheme = url.scheme?.lowercased() else { return .deny }
        if externalSchemes.contains(scheme) { return .openExternal(url) }
        guard scheme == "https", let host = url.host?.lowercased(), allowedHosts.contains(host) else {
            return .deny
        }
        return .allow
    }
}
