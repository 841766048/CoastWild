import Foundation

public enum IntegrationAPIError: Error, Equatable, Sendable {
    case network(URLError.Code)
    case invalidResponse
    case httpStatus(Int)
    case emptyResponse
    case invalidURL
    case missingEncryptionKey
    case encryption
    case decryption
    case invalidEnvelope
    case business(code: Int, message: String)

    var isRetryable: Bool {
        switch self {
        case .network, .invalidResponse, .httpStatus, .emptyResponse, .decryption,
             .invalidEnvelope, .business:
            return true
        case .invalidURL, .missingEncryptionKey, .encryption:
            return false
        }
    }
}
