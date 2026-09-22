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
        if let redactedJSON = redactedJSONSummary(from: withoutControls) {
            return String(redactedJSON.prefix(160))
        }
        let urlUserInfoStripped = replacing(
            #"([A-Za-z][A-Za-z0-9+.-]*://)[^\s/@]+@"#,
            in: withoutControls,
            with: "$1"
        )
        let urlParametersStripped = replacing(
            #"([A-Za-z][A-Za-z0-9+.-]*://[^\s?#]+)[?#][^\s]*"#,
            in: urlUserInfoStripped,
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
        let namedValuesRedacted = redactingSensitiveFields(in: schemeRedacted)
        return String(redactingJWS(in: namedValuesRedacted).prefix(160))
    }

    private static func redactedJSONSummary(from value: String) -> String? {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is [String: Any] || object is [Any] else { return nil }
        let redacted = redactingJSON(object)
        guard JSONSerialization.isValidJSONObject(redacted),
              let summary = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys]) else { return nil }
        return String(data: summary, encoding: .utf8)
    }

    private static func redactingJSON(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, entry in
                result[entry.key] = isSensitiveKey(entry.key) ? "[REDACTED]" : redactingJSON(entry.value)
            }
        }
        if let array = value as? [Any] {
            return array.map(redactingJSON)
        }
        return value
    }

    private static func redactingSensitiveFields(in value: String) -> String {
        let pattern = #"(?i)(\b([A-Za-z][A-Za-z0-9_-]*)\s*[:=]\s*)(?:\"[^\"]*\"|'[^']*'|[^\s,;}&]+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let matches = expression.matches(in: value, range: NSRange(value.startIndex..., in: value))
        var result = value

        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 2), in: value),
                  let prefixRange = Range(match.range(at: 1), in: value),
                  let fullRange = Range(match.range, in: value),
                  isSensitiveKey(String(value[keyRange])) else { continue }
            let prefix = String(value[prefixRange])
            result.replaceSubrange(fullRange, with: prefix + "[REDACTED]")
        }
        return result
    }

    private static func redactingJWS(in value: String) -> String {
        let pattern = #"\b([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]*)\.([A-Za-z0-9_-]+)\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let matches = expression.matches(in: value, range: NSRange(value.startIndex..., in: value))
        var result = ""
        var cursor = value.startIndex

        for match in matches {
            guard let fullRange = Range(match.range, in: value),
                  let headerRange = Range(match.range(at: 1), in: value) else { continue }
            result += value[cursor..<fullRange.lowerBound]
            if isJWSHeader(String(value[headerRange])) {
                result += "[REDACTED]"
            } else {
                result += value[fullRange]
            }
            cursor = fullRange.upperBound
        }
        result += value[cursor...]
        return result
    }

    private static func isJWSHeader(_ value: String) -> Bool {
        let padding = String(repeating: "=", count: (4 - value.count % 4) % 4)
        let base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/") + padding
        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return object["alg"] != nil
    }

    private static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
        return [
            "authorization", "token", "accesstoken", "refreshtoken", "device", "deviceid",
            "order", "orderid", "orderno", "receipt", "payload", "jws", "user", "userid", "userinfo",
        ].contains(normalized)
    }

    private static func replacing(_ pattern: String, in value: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..., in: value)
        return expression.stringByReplacingMatches(in: value, range: range, withTemplate: replacement)
    }
}
