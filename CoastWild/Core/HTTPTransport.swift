import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPTransportResponse: @unchecked Sendable {
    public let data: Data
    public let response: HTTPURLResponse

    public init(data: Data, response: HTTPURLResponse) {
        self.data = data
        self.response = response
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPTransportResponse
}

public struct URLSessionTransport: HTTPTransport {
    public typealias Sender = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let sender: Sender

    public init(session: URLSession = .shared) {
        sender = { request in
            try await session.data(for: request)
        }
    }

    public init(sender: @escaping Sender) {
        self.sender = sender
    }

    public func send(_ request: URLRequest) async throws -> HTTPTransportResponse {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await sender(request)
        } catch let error as URLError {
            throw IntegrationAPIError.network(error.code)
        } catch {
            throw IntegrationAPIError.invalidResponse
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntegrationAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw IntegrationAPIError.httpStatus(httpResponse.statusCode)
        }
        guard !data.isEmpty else {
            throw IntegrationAPIError.emptyResponse
        }
        return HTTPTransportResponse(data: data, response: httpResponse)
    }
}
