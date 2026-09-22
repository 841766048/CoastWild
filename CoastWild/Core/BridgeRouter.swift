import Foundation

public protocol BridgeMessageHandling: AnyObject {
    func handle(_ message: BridgeMessage)
}

public final class BridgeRouter {
    private let allowedHosts: Set<String>
    private weak var handler: BridgeMessageHandling?
    public init(allowedHosts: Set<String>, handler: BridgeMessageHandling) {
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() }); self.handler = handler
    }
    public func route(name: String, body: Any?, sourceURL: URL?, isMainFrame: Bool) throws {
        guard let topic = BridgeTopic(rawValue: name) else { throw BridgeError.unknownTopic(name) }
        guard isMainFrame else { throw BridgeError.untrustedFrame }
        guard sourceURL?.scheme?.lowercased() == "https", let host = sourceURL?.host?.lowercased(), allowedHosts.contains(host) else { throw BridgeError.untrustedSource }
        if topic == .onCreateOrder { throw BridgeError.unsupported(topic) }
        handler?.handle(try BridgeMessage.decode(topic: topic, body: body))
    }
}
