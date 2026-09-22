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
    private var loginGeneration = 0
    private var loggingOut = false

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
        let generation = loginGeneration
        let storedSession = await sessions.session()
        guard generation == loginGeneration else { return .idle }
        guard let session = storedSession else {
            currentState = .idle
            return currentState
        }

        do {
            _ = try await api.getConfig(session: session.requestSession)
            guard generation == loginGeneration else { return .idle }
            let strategy = try await api.getStrategy(session: session.requestSession)
            guard generation == loginGeneration else { return .idle }
            currentState = .authenticated(session: session, strategy: strategy)
        } catch {
            guard generation == loginGeneration else { return .idle }
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
        await deviceLogin(riskInfo: riskInfo, preserveSessionUntilStrategySucceeds: true)
    }

    public func logout() async {
        guard !loggingOut else { return }
        loggingOut = true
        currentState = .loading
        loginGeneration += 1
        defer {
            currentState = .idle
            loggingOut = false
        }
        await sessions.clear()
    }

    private func deviceLogin(riskInfo: String?, preserveSessionUntilStrategySucceeds: Bool = false) async -> RemoteLoginState {
        guard beginLoading() else { return currentState }
        let generation = loginGeneration

        do {
            _ = try await api.getConfig(session: .anonymous)
            guard generation == loginGeneration else { return .idle }
            let deviceID = try deviceIdentity.resolve()
            let relogin = await sessions.hasLoggedInBefore()
            guard generation == loginGeneration else { return .idle }
            let response = try await api.oauth(
                OAuthRequest(token: deviceID, relogin: relogin, riskInfo: riskInfo),
                session: .anonymous
            )
            guard generation == loginGeneration else { return .idle }
            let session: RemoteSession
            do {
                session = try RemoteSession(oauthResponse: response)
            } catch {
                currentState = .failed(.invalidOAuthResponse)
                return currentState
            }
            let backgroundStrategy = preserveSessionUntilStrategySucceeds
                ? try await api.getStrategy(session: session.requestSession) : nil
            guard generation == loginGeneration else { return .idle }
            do {
                try await sessions.save(session)
            } catch {
                guard generation == loginGeneration else { return .idle }
                currentState = .failed(.persistence)
                return currentState
            }
            guard generation == loginGeneration else { return .idle }
            await sessions.markLoginSucceeded()
            guard generation == loginGeneration else { return .idle }
            let strategy: JSONValue
            if let backgroundStrategy {
                strategy = backgroundStrategy
            } else {
                strategy = try await api.getStrategy(session: session.requestSession)
            }
            guard generation == loginGeneration else { return .idle }
            currentState = .authenticated(session: session, strategy: strategy)
        } catch {
            guard generation == loginGeneration else { return .idle }
            currentState = .failed(map(error))
        }
        return currentState
    }

    private func beginLoading() -> Bool {
        guard !loggingOut else { return false }
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
