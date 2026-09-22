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

/// Executes application effects independently of UIKit; the controller only supplies a weak sink.
@MainActor struct BusinessBridgeApplicationHandler {
    var backgroundLogin: () async -> RemoteLoginState
    var makeBootstrap: (RemoteSession, JSONValue) async throws -> BusinessWebBootstrap
    var sendBackgroundLoginSuccess: (BusinessWebBootstrap) throws -> Void
    var logout: () async throws -> Void
    var refreshEntitlements: () async throws -> Void
    var persistLanguage: (String) throws -> Void
    var refreshInterface: () -> Void
    var nativeLog: (String, Int, String) -> Void
    var showRecoverableFailure: () -> Void

    func handle(_ action: BusinessBridgeAction) async {
        do {
            switch action {
            case .backgroundLogin:
                switch await backgroundLogin() {
                case let .authenticated(session, strategy):
                    let bootstrap = try await makeBootstrap(session, strategy)
                    try sendBackgroundLoginSuccess(bootstrap)
                case let .failed(error):
                    throw error
                case .idle, .loading:
                    break
                }
            case .logout:
                try await logout()
            case .refreshEntitlements:
                try await refreshEntitlements()
            case let .setLanguage(language):
                try persistLanguage(BridgeLanguage.normalized(language))
                refreshInterface()
            case let .nativeLog(event, length, summary):
                nativeLog(event, length, summary)
            default:
                break
            }
        } catch {
            showRecoverableFailure()
        }
    }
}

public enum BridgeNativeLog {
    public static func sanitizedSummary(_ message: String) -> String {
        return String(sanitizedText(message).prefix(160))
    }

    private static func sanitizedText(_ value: String) -> String {
        if let redactedJSON = redactedJSONSummary(from: value) {
            return redactedJSON
        }

        // Digest parameters may contain spaces and commas. Preserve the original
        // line boundary until the complete credential payload has been removed.
        let controlsSeparated = String(String.UnicodeScalarView(value.unicodeScalars.map { scalar in
            scalar != "\r" && scalar != "\n" && CharacterSet.controlCharacters.contains(scalar) ? " " : scalar
        }))
        var placeholderPrefix = "__BRIDGE_JSON_"
        while controlsSeparated.contains(placeholderPrefix) { placeholderPrefix += "_" }
        var containers: [(placeholder: String, redacted: String)] = []
        var result = ""
        var cursor = controlsSeparated.startIndex
        var plainTextStart = cursor
        while cursor < controlsSeparated.endIndex {
            if (controlsSeparated[cursor] == "{" || controlsSeparated[cursor] == "["),
               let range = jsonContainerRange(in: controlsSeparated, from: cursor),
               let redactedJSON = redactedJSONSummary(from: String(controlsSeparated[range])) {
                let placeholder = placeholderPrefix + String(containers.count) + "__"
                containers.append((placeholder, redactedJSON))
                result += controlsSeparated[plainTextStart..<cursor]
                result += placeholder
                cursor = range.upperBound
                plainTextStart = cursor
            } else {
                cursor = controlsSeparated.index(after: cursor)
            }
        }
        result += controlsSeparated[plainTextStart...]
        // Protect structured containers before line-based redaction so Digest
        // text inside a JSON string cannot consume enclosing keys or brackets.
        result = replacing(
            #"(?i)(\bAuthorization[^\S\r\n]*[:=]?[^\S\r\n]*)Digest\b[^\r\n]*"#,
            in: result,
            with: "$1[REDACTED]"
        )
        // Digest can stand alone or follow Authorization on its own line.
        // Require a credential parameter and keep both whitespace and payload on that line.
        result = replacing(
            #"(?i)\bDigest[^\S\r\n]+(?=[A-Za-z][A-Za-z0-9_-]*[^\S\r\n]*=)[^\r\n]*"#,
            in: result,
            with: "[REDACTED]"
        )
        // Sanitize the surrounding text as one message so an enclosing sensitive
        // field or URL query also removes its entire embedded JSON value.
        result = sanitizedPlainText(result)
        let replacements = containers.compactMap { container -> (Range<String.Index>, String)? in
            guard let range = result.range(of: container.placeholder) else { return nil }
            return (range, container.redacted)
        }
        // Resolve every range before inserting JSON; decoded string contents must
        // never be interpreted as another container placeholder.
        for (range, redacted) in replacements.reversed() {
            result.replaceSubrange(range, with: redacted)
        }
        return result
    }

    private static func jsonContainerRange(in value: String, from start: String.Index) -> Range<String.Index>? {
        var closingBrackets: [Character] = []
        var insideString = false
        var escaped = false
        var cursor = start
        while cursor < value.endIndex {
            let character = value[cursor]
            if insideString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    insideString = false
                }
            } else {
                switch character {
                case "\"": insideString = true
                case "{": closingBrackets.append("}")
                case "[": closingBrackets.append("]")
                case "}", "]":
                    guard closingBrackets.popLast() == character else { return nil }
                    if closingBrackets.isEmpty {
                        return start..<value.index(after: cursor)
                    }
                default: break
                }
            }
            cursor = value.index(after: cursor)
        }
        return nil
    }

    private static func sanitizedPlainText(_ value: String) -> String {
        let withoutControls = String(String.UnicodeScalarView(
            value.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? " " : $0 }
        ))
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
        return redactingJWS(in: namedValuesRedacted)
    }

    private static func redactedJSONSummary(from value: String) -> String? {
        guard let data = value.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              object is [String: Any] || object is [Any] || object is String else { return nil }
        // Decoding a string removes one encoding layer before recursing, so a
        // string root eventually reaches ordinary text or a structured container.
        let redacted = redactingJSON(object)
        guard let summary = try? JSONSerialization.data(
            withJSONObject: redacted, options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes]
        ) else { return nil }
        return String(data: summary, encoding: .utf8)
    }

    private static func redactingJSON(_ value: Any) -> Any {
        if let string = value as? String {
            return sanitizedText(string)
        }
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
