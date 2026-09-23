import Foundation

public enum BridgeTopic: String, CaseIterable, Sendable {
    case logout = "Logout", backgroundLogin = "BackgroundLogin", didMoveToMainPage = "DidMoveToMainPage"
    case openAppBrowser = "OpenAppBrowser", openLink = "OpenLink", openInternalWeb = "OpenInternalWeb"
    case openAppSettings = "OpenAppSettings", openAppStoreReview = "OpenAppStoreReview"
    case enableEdgePan = "EnableEdgePan", newTppClose
    case updateLanguage = "UpdateLanguage", nativeLog = "NativeLog"

    public var acceptsEmptyBody: Bool {
        switch self {
        case .logout, .backgroundLogin, .didMoveToMainPage, .openAppSettings,
             .openAppStoreReview, .newTppClose: true
        default: false
        }
    }
}

public enum BridgeError: Error, Equatable, Sendable {
    case unknownTopic(String)
    case invalidPayload(BridgeTopic, String)
    case untrustedSource
    case untrustedFrame
    case unsupported(BridgeTopic)
}

public struct InternalWebPayload: Equatable, Sendable {
    public let url: URL; public let showsNavigationBar: Bool; public let title: String
    public init(url: URL, showsNavigationBar: Bool, title: String) {
        self.url = url; self.showsNavigationBar = showsNavigationBar; self.title = title
    }
}
public struct EdgePanPayload: Equatable, Sendable {
    public let isEnabled: Bool; public let isLeftEdge: Bool
    public init(isEnabled: Bool, isLeftEdge: Bool) { self.isEnabled = isEnabled; self.isLeftEdge = isLeftEdge }
}
public enum BridgeMessage: Equatable, Sendable {
    case logout, backgroundLogin, didMoveToMainPage
    case openAppBrowser(URL), openLink(URL), openInternalWeb(InternalWebPayload)
    case openAppSettings, openAppStoreReview, enableEdgePan(EdgePanPayload), newTppClose
    case updateLanguage(String), nativeLog(String)

    public static func decode(topic: BridgeTopic, body: Any?) throws -> Self {
        func invalid(_ field: String) -> BridgeError { .invalidPayload(topic, field) }
        func dictionary() throws -> [String: Any] {
            guard let value = body as? [String: Any] else { throw invalid("body") }; return value
        }
        func nonempty(_ value: Any?, field: String) throws -> String {
            guard let string = value as? String, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw invalid(field) }
            return string
        }
        func httpsURL(_ value: Any?) throws -> URL {
            let string = try nonempty(value, field: "url")
            guard let url = URL(string: string), url.scheme?.lowercased() == "https", url.host?.isEmpty == false else { throw invalid("url") }
            return url
        }
        func flag(_ value: Any?, field: String) throws -> Bool {
            guard let string = value as? String, string == "0" || string == "1" else { throw invalid(field) }
            return string == "1"
        }
        switch topic {
        case .openAppBrowser: return .openAppBrowser(try httpsURL(body))
        case .openLink: return .openLink(try httpsURL(body))
        case .openInternalWeb:
            let value = try dictionary()
            return .openInternalWeb(.init(url: try httpsURL(value["url"]), showsNavigationBar: try flag(value["show"], field: "show"), title: (value["title"] as? String) ?? ""))
        case .enableEdgePan:
            let value = try dictionary(); return .enableEdgePan(.init(isEnabled: try flag(value["enable"], field: "enable"), isLeftEdge: try flag(value["left"], field: "left")))
        case .updateLanguage: return .updateLanguage(try nonempty(body, field: "language"))
        case .nativeLog: return .nativeLog(try nonempty(body, field: "message"))
        case .logout: return .logout
        case .backgroundLogin: return .backgroundLogin
        case .didMoveToMainPage: return .didMoveToMainPage
        case .openAppSettings: return .openAppSettings
        case .openAppStoreReview: return .openAppStoreReview
        case .newTppClose: return .newTppClose
        }
    }

}
