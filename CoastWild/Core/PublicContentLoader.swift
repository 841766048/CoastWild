import Foundation

public enum PublicContentLoadState: Equatable {
    case idle, loading, loaded, failed
}

/// Keeps the last validated value while refreshing; explicit retries bypass the automatic cooldown.
public final class PublicContentLoader<Value> {
    public private(set) var current: Value?
    public private(set) var state: PublicContentLoadState
    public var onChange: (() -> Void)?
    private var nextCheck = Date.distantPast

    public init(cached: Value? = nil) {
        current = cached
        state = cached == nil ? .idle : .loaded
    }

    @MainActor public func refresh(force: Bool = false, load: () async throws -> Value) async {
        guard state != .loading, force || Date() >= nextCheck else { return }
        state = .loading
        onChange?()
        do {
            let value = try await load()
            try Task.checkCancellation()
            current = value
            state = .loaded
            nextCheck = Date().addingTimeInterval(300)
        } catch {
            state = .failed
            nextCheck = Date().addingTimeInterval(30)
        }
        onChange?()
    }
}
