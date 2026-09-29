import Foundation

public enum StartupRoute: Equatable, Sendable {
    case loading, login, main, retry

    public init(state: RemoteLoginState) {
        switch state {
        case .idle: self = .login
        case .loading: self = .loading
        case .authenticated: self = .main
        case .failed(.api(.httpStatus(401))): self = .login
        case .failed: self = .retry
        }
    }
}

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
        case let .authenticated(session):
            self = .authenticated(userID: session.userID)
        case .failed:
            self = isConnected ? .retryableFailure : .offline
        }
    }
}
