import Foundation

public protocol RemoteAuthenticationAPI: Sendable {
    func getConfig(session: RequestSession) async throws -> IntegrationConfigBundle
    func oauth(_ request: OAuthRequest, session: RequestSession) async throws -> JSONValue
    func getStrategy(session: RequestSession) async throws -> JSONValue
}

public enum RemoteLoginError: Error, Equatable, Sendable {
    case api(IntegrationAPIError)
    case invalidOAuthResponse
    case deviceIdentity
    case persistence
    case unexpected
}

public enum RemoteLoginState: Equatable, Sendable {
    case idle
    case loading
    case authenticated(session: RemoteSession, strategy: JSONValue)
    case failed(RemoteLoginError)
}

public actor RemoteSessionCoordinator {
    private let api: any RemoteAuthenticationAPI
    private let deviceIdentity: DeviceIdentityStore
    private let sessions: RemoteSessionStore
    private var currentState: RemoteLoginState = .idle

    public init(
        api: any RemoteAuthenticationAPI,
        deviceIdentity: DeviceIdentityStore,
        sessions: RemoteSessionStore
    ) {
        self.api = api
        self.deviceIdentity = deviceIdentity
        self.sessions = sessions
    }

    public func state() -> RemoteLoginState {
        currentState
    }

    @discardableResult
    public func automaticLogin() async -> RemoteLoginState {
        guard beginLoading() else { return currentState }
        guard let session = await sessions.session() else {
            currentState = .idle
            return currentState
        }

        do {
            _ = try await api.getConfig(session: session.requestSession)
            let strategy = try await api.getStrategy(session: session.requestSession)
            currentState = .authenticated(session: session, strategy: strategy)
        } catch {
            currentState = .failed(map(error))
        }
        return currentState
    }

    @discardableResult
    public func manualLogin(riskInfo: String?) async -> RemoteLoginState {
        await deviceLogin(riskInfo: riskInfo)
    }

    @discardableResult
    public func backgroundLogin(riskInfo: String?) async -> RemoteLoginState {
        await deviceLogin(riskInfo: riskInfo)
    }

    public func logout() async {
        await sessions.clear()
        currentState = .idle
    }

    private func deviceLogin(riskInfo: String?) async -> RemoteLoginState {
        guard beginLoading() else { return currentState }

        do {
            _ = try await api.getConfig(session: .anonymous)
            let deviceID = try deviceIdentity.resolve()
            let relogin = await sessions.hasLoggedInBefore()
            let response = try await api.oauth(
                OAuthRequest(token: deviceID, relogin: relogin, riskInfo: riskInfo),
                session: .anonymous
            )
            let session: RemoteSession
            do {
                session = try RemoteSession(oauthResponse: response)
            } catch {
                currentState = .failed(.invalidOAuthResponse)
                return currentState
            }
            do {
                try await sessions.save(session)
            } catch {
                currentState = .failed(.persistence)
                return currentState
            }
            await sessions.markLoginSucceeded()
            let strategy = try await api.getStrategy(session: session.requestSession)
            currentState = .authenticated(session: session, strategy: strategy)
        } catch {
            currentState = .failed(map(error))
        }
        return currentState
    }

    private func beginLoading() -> Bool {
        if case .loading = currentState {
            return false
        }
        currentState = .loading
        return true
    }

    private func map(_ error: Error) -> RemoteLoginError {
        if let apiError = error as? IntegrationAPIError {
            return .api(apiError)
        }
        if error is DeviceIdentityError {
            return .deviceIdentity
        }
        if error is RemoteSessionError {
            return .persistence
        }
        return .unexpected
    }
}
