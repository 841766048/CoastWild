import Foundation

public final class BridgeEventEmitter {
    private let center: NotificationCenter
    private let evaluate: (String) -> Void
    private var tokens: [NSObjectProtocol] = []

    public init(
        center: NotificationCenter = .default,
        resumedName: Notification.Name,
        pausedName: Notification.Name,
        evaluate: @escaping (String) -> Void
    ) {
        self.center = center
        self.evaluate = evaluate
        tokens = [
            center.addObserver(forName: resumedName, object: nil, queue: nil) { [weak self] _ in
                self?.evaluate(BridgeEventEncoder.lifecycle(.resumed))
            },
            center.addObserver(forName: pausedName, object: nil, queue: nil) { [weak self] _ in
                self?.evaluate(BridgeEventEncoder.lifecycle(.paused))
            },
        ]
    }

    public func emitKeyboard(height: Double, duration: Double) {
        evaluate(BridgeEventEncoder.keyboard(height: height, duration: duration))
    }

    deinit { tokens.forEach(center.removeObserver) }
}
