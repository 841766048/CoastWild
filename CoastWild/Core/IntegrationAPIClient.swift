import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public actor IntegrationKeyStore {
    private var derivedKey: String?

    public init(initialKey: String? = nil) {
        derivedKey = initialKey
    }

    public func key() -> String? {
        derivedKey
    }

    public func store(_ key: String) {
        derivedKey = key
    }
}

public protocol IntegrationCiphering: Sendable {
    func encryptJSONObject(_ object: [String: Any], key: String) throws -> String
    func decryptJSONObject(_ base64: String, key: String) throws -> [String: Any]
}

public struct DefaultIntegrationCipher: IntegrationCiphering {
    public init() {}

    public func encryptJSONObject(_ object: [String: Any], key: String) throws -> String {
        try IntegrationCipher.encryptJSONObject(object, key: key)
    }

    public func decryptJSONObject(_ base64: String, key: String) throws -> [String: Any] {
        try IntegrationCipher.decryptJSONObject(base64, key: key)
    }
}

public final class IntegrationAPIClient: @unchecked Sendable {
    public typealias Sleeper = @Sendable () async -> Void

    private let primaryHost: URL
    private let paths: IntegrationEndpointPaths
    private let transport: any HTTPTransport
    private let cipher: any IntegrationCiphering
    private let contextProvider: any RequestContextProviding
    private let keyStore: IntegrationKeyStore
    private let runtimeConfiguration: IntegrationRuntimeConfiguration?
    private let sleeper: Sleeper

    public init(
        primaryHost: URL,
        paths: IntegrationEndpointPaths = .default,
        transport: any HTTPTransport = URLSessionTransport(),
        cipher: any IntegrationCiphering = DefaultIntegrationCipher(),
        contextProvider: any RequestContextProviding,
        keyStore: IntegrationKeyStore,
        runtimeConfiguration: IntegrationRuntimeConfiguration? = nil,
        sleeper: @escaping Sleeper = {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    ) {
        self.primaryHost = primaryHost
        self.paths = paths
        self.transport = transport
        self.cipher = cipher
        self.contextProvider = contextProvider
        self.keyStore = keyStore
        self.runtimeConfiguration = runtimeConfiguration
        self.sleeper = sleeper
    }

    public func getConfig(session: RequestSession) async throws -> IntegrationConfigBundle {
        let configKeyData: Data
        do {
            configKeyData = try IntegrationKeyDeriver.configKey(from: primaryHost)
        } catch {
            throw IntegrationAPIError.encryption
        }
        let configKey = String(decoding: configKeyData, as: UTF8.self)
        let data = try await post(
            path: paths.getConfig,
            parameters: ["ver": 0],
            key: configKey,
            session: session
        )
        guard case let .object(object) = data,
              let k2 = object["k2"]?.stringValue,
              let k3 = object["k3"]?.stringValue,
              let k4 = object["k4"]?.stringValue
        else {
            throw IntegrationAPIError.invalidEnvelope
        }

        let derivedKey: String
        let encryptedConfiguration: String
        do {
            derivedKey = try IntegrationKeyDeriver.derivedKey(k2: k2, k3: k3)
            guard let k4Data = Data(base64Encoded: k4),
                  let decodedK4 = String(data: k4Data, encoding: .utf8)
            else {
                throw IntegrationAPIError.invalidEnvelope
            }
            encryptedConfiguration = decodedK4
        } catch let error as IntegrationAPIError {
            throw error
        } catch {
            throw IntegrationAPIError.invalidEnvelope
        }

        let configurationObject: [String: Any]
        do {
            configurationObject = try cipher.decryptJSONObject(
                encryptedConfiguration,
                key: derivedKey
            )
        } catch {
            throw IntegrationAPIError.decryption
        }
        let configuration = try JSONValue(any: configurationObject)
        await runtimeConfiguration?.apply(configuration: configuration)
        await keyStore.store(derivedKey)
        return IntegrationConfigBundle(
            k2: k2,
            k3: k3,
            k4: k4,
            configuration: configuration
        )
    }

    public func getStrategy(session: RequestSession) async throws -> JSONValue {
        try await postWithDerivedKey(path: paths.getStrategy, parameters: [:], session: session)
    }

    public func oauth(_ request: OAuthRequest, session: RequestSession) async throws -> JSONValue {
        try await postWithDerivedKey(path: paths.oauth, parameters: request.parameters, session: session)
    }

    public func createRecharge(
        _ request: RechargeRequest,
        session: RequestSession
    ) async throws -> JSONValue {
        try await postWithDerivedKey(
            path: paths.createRecharge,
            parameters: request.parameters,
            session: session
        )
    }

    public func verifyReceipt(
        _ request: ReceiptVerificationRequest,
        session: RequestSession
    ) async throws -> JSONValue {
        try await postWithDerivedKey(
            path: paths.paymentRecharge,
            parameters: request.parameters,
            session: session
        )
    }

    public func submitAttribution(
        _ request: AttributionRequest,
        session: RequestSession
    ) async throws -> JSONValue {
        try await postWithDerivedKey(
            path: paths.ascribeRecord,
            parameters: request.parameters,
            session: session
        )
    }

    private func postWithDerivedKey(
        path: String,
        parameters: [String: Any],
        session: RequestSession
    ) async throws -> JSONValue {
        guard let key = await keyStore.key(), !key.isEmpty else {
            throw IntegrationAPIError.missingEncryptionKey
        }
        return try await post(path: path, parameters: parameters, key: key, session: session)
    }

    private func post(
        path: String,
        parameters: [String: Any],
        key: String,
        session: RequestSession
    ) async throws -> JSONValue {
        guard let url = endpointURL(path: path) else {
            throw IntegrationAPIError.invalidURL
        }
        var body = parameters
        body["http_headers"] = contextProvider.headers(session: session)

        let encryptedBody: String
        do {
            encryptedBody = try cipher.encryptJSONObject(body, key: key)
        } catch {
            throw IntegrationAPIError.encryption
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(encryptedBody.utf8)

        var lastError: IntegrationAPIError = .invalidResponse
        for attempt in 1...3 {
            do {
                let response = try await transport.send(request)
                guard let encryptedResponse = String(data: response.data, encoding: .utf8) else {
                    throw IntegrationAPIError.decryption
                }
                let envelope: [String: Any]
                do {
                    envelope = try cipher.decryptJSONObject(encryptedResponse, key: key)
                } catch {
                    throw IntegrationAPIError.decryption
                }
                guard let code = (envelope["code"] as? NSNumber)?.intValue else {
                    throw IntegrationAPIError.invalidEnvelope
                }
                let message = envelope["msg"] as? String ?? ""
                guard code == 0 else {
                    throw IntegrationAPIError.business(code: code, message: message)
                }
                return try JSONValue(any: envelope["data"] ?? NSNull())
            } catch let error as IntegrationAPIError {
                lastError = error
            } catch let error as URLError {
                lastError = .network(error.code)
            } catch {
                lastError = .invalidResponse
            }

            guard lastError.isRetryable, attempt < 3 else {
                throw lastError
            }
            await sleeper()
        }
        throw lastError
    }

    private func endpointURL(path: String) -> URL? {
        guard var components = URLComponents(url: primaryHost, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

extension IntegrationAPIClient: RemoteAuthenticationAPI {}
