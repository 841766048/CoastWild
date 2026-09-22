import Foundation

public enum BusinessBridgeCallback: Equatable, Sendable {
    case closeInternalWeb
    case openVIPService
    case recharge
}

public enum BusinessBridgeAction: Equatable, Sendable {
    case backgroundLogin
    case revealBusinessWeb
    case presentBrowser(URL)
    case openExternalLink(URL)
    case openInternalWeb(InternalWebPayload)
    case openSettings
    case requestReview
    case setEdgePan(EdgePanPayload)
    case logout
    case setLanguage(String)
    case refreshEntitlements
    case nativeLog(event: String, messageLength: Int, summary: String)
    case callback(BusinessBridgeCallback)
}

public enum BusinessBridgeActionPlanner {
    public static func action(for message: BridgeMessage) -> BusinessBridgeAction? {
        switch message {
        case .openAppPurchase, .logPurchase, .getProductPrice, .onCreateOrder:
            nil
        case .backgroundLogin:
            .backgroundLogin
        case .didMoveToMainPage:
            .revealBusinessWeb
        case let .openAppBrowser(url):
            .presentBrowser(url)
        case let .openLink(url):
            .openExternalLink(url)
        case let .openInternalWeb(payload):
            .openInternalWeb(payload)
        case .openAppSettings:
            .openSettings
        case .openAppStoreReview:
            .requestReview
        case let .enableEdgePan(payload):
            .setEdgePan(payload)
        case .newTppClose:
            .callback(.closeInternalWeb)
        case .openVipService:
            .callback(.openVIPService)
        case .recharge:
            .callback(.recharge)
        case .updateCoins:
            .refreshEntitlements
        case let .updateLanguage(language):
            .setLanguage(BridgeLanguage.normalized(language))
        case let .nativeLog(message):
            .nativeLog(event: "NativeLog", messageLength: message.count, summary: BridgeNativeLog.sanitizedSummary(message))
        case .logout:
            .logout
        }
    }
}

public enum BridgeLanguage {
    public static func normalized(_ language: String) -> String {
        language.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
            .hasPrefix("zh") ? "zh-Hans" : "en"
    }
}

public enum BridgeNativeLog {
    public static func sanitizedSummary(_ message: String) -> String {
        let withoutControls = String(String.UnicodeScalarView(
            message.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        ))
        let urlParametersStripped = replacing(
            #"([A-Za-z][A-Za-z0-9+.-]*://[^\s?#]+)[?#][^\s]*"#,
            in: withoutControls,
            with: "$1"
        )
        let authorizationRedacted = replacing(
            #"(?i)(\bAuthorization\s*[:=]?\s*)(?:(?:Bearer|Basic|Digest|Token|Negotiate)\s+)?[^\s,;]+"#,
            in: urlParametersStripped,
            with: "$1[REDACTED]"
        )
        let schemeRedacted = replacing(
            #"(?i)\b(?:Bearer|Basic|Digest|Negotiate)\s+[^\s,;]+"#,
            in: authorizationRedacted,
            with: "[REDACTED]"
        )
        let namedValuesRedacted = replacing(
            #"(?i)(\b(?:token|deviceId|orderId|receipt|userInfo)\s*[:=]\s*)(?:\"[^\"]*\"|'[^']*'|[^\s,;}&]+)"#,
            in: schemeRedacted,
            with: "$1[REDACTED]"
        )
        let jwsRedacted = replacing(
            #"\b[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b"#,
            in: namedValuesRedacted,
            with: "[REDACTED]"
        )
        return String(jwsRedacted.prefix(160))
    }

    private static func replacing(_ pattern: String, in value: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }
}
