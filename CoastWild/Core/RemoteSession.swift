import Foundation

public enum RemoteSessionError: Error, Equatable, Sendable {
    case invalidOAuthResponse
    case persistence
}

public struct RemoteSession: Codable, Equatable, Sendable {
    public let token: String
    public let userID: String
    public let isFirstRegister: Int
    public let responseData: Data

    public var isFirstRegistration: Bool {
        isFirstRegister == 1
    }

    public var requestSession: RequestSession {
        RequestSession(token: token, userID: userID)
    }

    public init(oauthResponse: JSONValue) throws {
        guard case let .object(object) = oauthResponse,
              let token = Self.nonempty(object["token"]?.stringValue),
              case let .object(userInfo)? = object["userInfo"],
              let userID = Self.nonempty(userInfo["userId"]?.stringValue),
              case let .number(firstRegisterNumber)? = object["isFirstRegister"],
              firstRegisterNumber.rounded() == firstRegisterNumber,
              firstRegisterNumber >= Double(Int.min),
              firstRegisterNumber <= Double(Int.max)
        else {
            throw RemoteSessionError.invalidOAuthResponse
        }

        let responseData: Data
        do {
            responseData = try JSONSerialization.data(
                withJSONObject: oauthResponse.foundationObject,
                options: [.sortedKeys]
            )
        } catch {
            throw RemoteSessionError.invalidOAuthResponse
        }

        self.token = token
        self.userID = userID
        isFirstRegister = Int(firstRegisterNumber)
        self.responseData = responseData
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }
}

extension JSONValue {
    var foundationObject: Any {
        switch self {
        case let .object(value):
            return value.mapValues(\.foundationObject)
        case let .array(value):
            return value.map(\.foundationObject)
        case let .string(value):
            return value
        case let .number(value):
            return value
        case let .bool(value):
            return value
        case .null:
            return NSNull()
        }
    }
}
