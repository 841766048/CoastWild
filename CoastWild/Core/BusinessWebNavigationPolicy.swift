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

    public func validatedURL(for action: BusinessBridgeAction) -> URL? {
        let url: URL
        switch action {
        case let .presentBrowser(value), let .openExternalLink(value):
            url = value
        default:
            return nil
        }
        guard url.scheme?.lowercased() == "https", url.host?.isEmpty == false else { return nil }
        return url
    }
}

public struct BusinessWebLocalActionState: Equatable, Sendable {
    public private(set) var isRevealed = false
    public private(set) var edgePan = EdgePanPayload(isEnabled: false, isLeftEdge: true)

    public init() {}

    public mutating func beginLoading() {
        isRevealed = false
    }

    @discardableResult
    public mutating func reveal() -> Bool {
        guard !isRevealed else { return false }
        isRevealed = true
        return true
    }

    public mutating func setEdgePan(_ payload: EdgePanPayload) {
        edgePan = payload
    }
}

public enum BusinessBridgeApplicationDelivery: Equatable, Sendable {
    case action(BusinessBridgeAction)
    case legacyMessage(BridgeMessage)
    case discard
}

public enum BusinessBridgeApplicationDeliveryPolicy {
    public static func delivery(
        action: BusinessBridgeAction,
        originalMessage: BridgeMessage,
        hasActionSink: Bool
    ) -> BusinessBridgeApplicationDelivery {
        if hasActionSink { return .action(action) }
        if case .nativeLog = action { return .discard }
        if case .nativeLog = originalMessage { return .discard }
        return .legacyMessage(originalMessage)
    }
}

public struct BusinessWebEdgePanDecision: Equatable, Sendable {
    public let shouldEnableRecognizer: Bool
    public let shouldBeginWebGesture: Bool
    public let shouldNavigationPopWaitForWebGesture: Bool

    public init(
        shouldEnableRecognizer: Bool,
        shouldBeginWebGesture: Bool,
        shouldNavigationPopWaitForWebGesture: Bool
    ) {
        self.shouldEnableRecognizer = shouldEnableRecognizer
        self.shouldBeginWebGesture = shouldBeginWebGesture
        self.shouldNavigationPopWaitForWebGesture = shouldNavigationPopWaitForWebGesture
    }
}

public enum BusinessWebEdgePanPolicy {
    public static func decision(
        payload: EdgePanPayload,
        webCanGoBack: Bool,
        isNavigationRoot: Bool,
        isControllerVisible: Bool,
        isOtherRecognizerCurrentNavigationPop: Bool
    ) -> BusinessWebEdgePanDecision {
        let shouldEnableRecognizer = isControllerVisible && payload.isEnabled
        let shouldBeginWebGesture = shouldEnableRecognizer && webCanGoBack
        let shouldNavigationPopWaitForWebGesture = shouldBeginWebGesture
            && payload.isLeftEdge
            && !isNavigationRoot
            && isOtherRecognizerCurrentNavigationPop
        return .init(
            shouldEnableRecognizer: shouldEnableRecognizer,
            shouldBeginWebGesture: shouldBeginWebGesture,
            shouldNavigationPopWaitForWebGesture: shouldNavigationPopWaitForWebGesture
        )
    }
}
