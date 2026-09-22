import Foundation

public actor RemoteSessionStore {
    public static let sessionKey = "LanlinLoginData"
    public static let loginFlagKey = "logindKey"

    private let defaults: UserDefaults
    private var current: RemoteSession?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.sessionKey),
           let decoded = try? JSONDecoder().decode(RemoteSession.self, from: data),
           !decoded.token.isEmpty,
           !decoded.userID.isEmpty
        {
            current = decoded
        } else {
            current = nil
            defaults.removeObject(forKey: Self.sessionKey)
        }
    }

    public func session() -> RemoteSession? {
        current
    }

    public func save(_ session: RemoteSession) throws {
        do {
            defaults.set(try JSONEncoder().encode(session), forKey: Self.sessionKey)
            current = session
        } catch {
            throw RemoteSessionError.persistence
        }
    }

    public func clear() {
        current = nil
        defaults.removeObject(forKey: Self.sessionKey)
    }

    public func hasLoggedInBefore() -> Bool {
        defaults.bool(forKey: Self.loginFlagKey)
    }

    public func markLoginSucceeded() {
        defaults.set(true, forKey: Self.loginFlagKey)
    }
}
