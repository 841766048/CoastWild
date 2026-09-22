import Foundation

public enum RemoteLoginPresentation: Equatable, Sendable {
    case ready
    case loading
    case authenticated(userID: String)
    case offline
    case retryableFailure

    public init(state: RemoteLoginState, isConnected: Bool) {
        switch state {
        case .idle:
            self = .ready
        case .loading:
            self = .loading
        case let .authenticated(session, _):
            self = .authenticated(userID: session.userID)
        case .failed:
            self = isConnected ? .retryableFailure : .offline
        }
    }
}
