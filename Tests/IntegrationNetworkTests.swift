import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import CoastWildCore

final class IntegrationNetworkTests: XCTestCase {
    func testGetConfigUsesHostKeyAndCachesDerivedKey() async throws {
        let host = URL(string: "https://test-app.bigegg.work")!
        let derivedKey = "1234567890abcdeffedcba9876543210"
        let encryptedConfiguration = try IntegrationCipher.encryptJSONObject(
            ["webIndexUrl": "https://h5.example.com"],
            key: derivedKey
        )
        let configData: [String: Any] = [
            "k2": Data("1234567890abcdef".utf8).base64EncodedString(),
            "k3": Data("fedcba9876543210".utf8).base64EncodedString(),
            "k4": Data(encryptedConfiguration.utf8).base64EncodedString(),
        ]
        let response = try encryptedResponse(
            ["code": 0, "msg": "", "data": configData],
            key: "test-app.bigegg.work",
            url: host
        )
        let transport = ScriptedTransport(results: [.success(response)])
        let keyStore = IntegrationKeyStore()
        let client = makeClient(host: host, transport: transport, keyStore: keyStore)

        let bundle = try await client.getConfig(session: .anonymous)
        let recordedRequests = await transport.requests()
        let request = try XCTUnwrap(recordedRequests.first)
        let encryptedBody = try XCTUnwrap(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        let requestBody = try IntegrationCipher.decryptJSONObject(
            encryptedBody,
            key: "test-app.bigegg.work"
        )

        XCTAssertEqual(request.url?.path, IntegrationEndpointPaths.default.getConfig)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(requestBody["ver"] as? Int, 0)
        XCTAssertNotNil(requestBody["http_headers"] as? [String: String])
        XCTAssertEqual(bundle.configuration["webIndexUrl"], .string("https://h5.example.com"))
        let cachedKey = await keyStore.key()
        XCTAssertEqual(cachedKey, derivedKey)
    }

    func testFiveSecretEndpointsUseDerivedKeyAndExpectedParameters() async throws {
        let host = URL(string: "https://test-app.bigegg.work")!
        let key = "1234567890abcdeffedcba9876543210"
        let response = try encryptedResponse(
            ["code": 0, "msg": "", "data": ["ok": true]],
            key: key,
            url: host
        )
        let transport = ScriptedTransport(results: Array(repeating: .success(response), count: 5))
        let client = makeClient(
            host: host,
            transport: transport,
            keyStore: IntegrationKeyStore(initialKey: key)
        )
        let session = RequestSession(token: "session", userID: "user")

        _ = try await client.getStrategy(session: session)
        _ = try await client.oauth(
            OAuthRequest(token: "device-123", relogin: true, riskInfo: "risk"),
            session: session
        )
        _ = try await client.createRecharge(
            RechargeRequest(goodsCode: "sku.1", paySource: "profile", invitationID: "invite"),
            session: session
        )
        _ = try await client.verifyReceipt(
            ReceiptVerificationRequest(
                orderNumber: "order-1",
                receipt: "receipt-data",
                transactionID: "transaction-1"
            ),
            session: session
        )
        _ = try await client.submitAttribution(
            AttributionRequest(
                package: "test.duckegg.ios",
                version: "2.3.4",
                deviceID: "device-123",
                userID: "user",
                source: "network",
                adGroupID: "group",
                adSetID: "creative",
                campaignID: "campaign",
                sdk: "AJ",
                sdkVersion: "5.4.0"
            ),
            session: session
        )

        let requests = await transport.requests()
        XCTAssertEqual(requests.map { $0.url?.path }, [
            IntegrationEndpointPaths.default.getStrategy,
            IntegrationEndpointPaths.default.oauth,
            IntegrationEndpointPaths.default.createRecharge,
            IntegrationEndpointPaths.default.paymentRecharge,
            IntegrationEndpointPaths.default.ascribeRecord,
        ])
        let bodies = try requests.map { request in
            try IntegrationCipher.decryptJSONObject(
                String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)!,
                key: key
            )
        }
        XCTAssertEqual(bodies[1]["oauthType"] as? String, "4")
        XCTAssertEqual(bodies[1]["relogin"] as? String, "1")
        XCTAssertEqual(bodies[1]["info"] as? String, "risk")
        XCTAssertEqual(bodies[2]["goodsCode"] as? String, "sku.1")
        XCTAssertEqual(bodies[2]["entry"] as? String, "profile")
        XCTAssertEqual(bodies[2]["source"] as? String, "invite")
        XCTAssertEqual(bodies[2]["payChannel"] as? String, "IAP")
        XCTAssertEqual(bodies[3]["orderNo"] as? String, "order-1")
        XCTAssertEqual(bodies[3]["payload"] as? String, "receipt-data")
        XCTAssertEqual(bodies[3]["transactionId"] as? String, "transaction-1")
        XCTAssertEqual(bodies[3]["type"] as? String, "1")
        XCTAssertEqual(bodies[4]["attributionSdk"] as? String, "AJ")
        XCTAssertTrue(bodies.allSatisfy { $0["http_headers"] != nil })
    }

    func testRequestRetriesTwiceThenReturnsThirdSuccess() async throws {
        let host = URL(string: "https://test-app.bigegg.work")!
        let key = "1234567890abcdeffedcba9876543210"
        let success = try encryptedResponse(
            ["code": 0, "msg": "", "data": ["attempt": 3]],
            key: key,
            url: host
        )
        let transport = ScriptedTransport(results: [
            .failure(IntegrationAPIError.network(.timedOut)),
            .failure(IntegrationAPIError.emptyResponse),
            .success(success),
        ])
        let sleeper = SleepRecorder()
        let client = makeClient(
            host: host,
            transport: transport,
            keyStore: IntegrationKeyStore(initialKey: key),
            sleeper: { await sleeper.record() }
        )

        let result = try await client.getStrategy(session: .anonymous)
        let requestCount = await transport.requests().count
        let sleepCount = await sleeper.count()

        XCTAssertEqual(result["attempt"], .number(3))
        XCTAssertEqual(requestCount, 3)
        XCTAssertEqual(sleepCount, 2)
    }

    func testRequestStopsAfterThreeBusinessFailures() async throws {
        let host = URL(string: "https://test-app.bigegg.work")!
        let key = "1234567890abcdeffedcba9876543210"
        let failure = try encryptedResponse(
            ["code": 42, "msg": "retry me", "data": NSNull()],
            key: key,
            url: host
        )
        let transport = ScriptedTransport(results: Array(repeating: .success(failure), count: 3))
        let client = makeClient(
            host: host,
            transport: transport,
            keyStore: IntegrationKeyStore(initialKey: key),
            sleeper: { }
        )

        await assertThrows(.business(code: 42, message: "retry me")) {
            _ = try await client.getStrategy(session: .anonymous)
        }
        let requestCount = await transport.requests().count
        XCTAssertEqual(requestCount, 3)
    }

    func testMissingDerivedKeyDoesNotStartOrRetryRequest() async {
        let transport = ScriptedTransport(results: [])
        let client = makeClient(
            transport: transport,
            keyStore: IntegrationKeyStore(),
            sleeper: { XCTFail("Missing key must not sleep or retry") }
        )

        await assertThrows(.missingEncryptionKey) {
            _ = try await client.getStrategy(session: .anonymous)
        }
        let requestCount = await transport.requests().count
        XCTAssertEqual(requestCount, 0)
    }

    func testRequestContextBuildsAllFixedAndConditionalHeaders() {
        let provider = makeContextProvider(
            riskAreaCode: "TW",
            attributionSDK: "AF",
            adjustSDKVersion: "5.4.0"
        )

        let headers = provider.headers(
            session: RequestSession(token: "session-token", userID: "user-42")
        )

        XCTAssertEqual(headers.count, 19)
        XCTAssertEqual(headers["device-id"], "device-123")
        XCTAssertEqual(headers["model"], "iPhone15,2")
        XCTAssertEqual(headers["lang"], "zh")
        XCTAssertEqual(headers["sys_lan"], "zh")
        XCTAssertEqual(headers["Authorization"], "Bearer session-token")
        XCTAssertEqual(headers["is_anchor"], "false")
        XCTAssertEqual(headers["platform"], "iOS")
        XCTAssertEqual(headers["ver"], "2.3.4")
        XCTAssertEqual(headers["pkg"], "test.duckegg.ios")
        XCTAssertEqual(headers["time_zone"], "Asia/Taipei")
        XCTAssertEqual(headers["device_lang"], "zh")
        XCTAssertEqual(headers["device_country"], "TW")
        XCTAssertEqual(headers["platform_ver"], "17.5")
        XCTAssertEqual(headers["system_language"], "zh_TW")
        XCTAssertEqual(headers["user_id"], "user-42")
        XCTAssertEqual(headers["sec_ver"], "0")
        XCTAssertEqual(headers["rc_type"], "TW")
        XCTAssertEqual(headers["attribution_sdk"], "AF")
        XCTAssertEqual(headers["attribution_sdk_ver"], "0.0.0")
    }

    func testRequestContextUsesAdjustDefaultsAndOmitsBlankRiskArea() {
        let provider = makeContextProvider(
            riskAreaCode: "",
            attributionSDK: "unexpected",
            adjustSDKVersion: "5.4.0"
        )

        let headers = provider.headers(session: .anonymous)

        XCTAssertNil(headers["rc_type"])
        XCTAssertEqual(headers["Authorization"], "Bearer ")
        XCTAssertEqual(headers["user_id"], "")
        XCTAssertEqual(headers["attribution_sdk"], "AJ")
        XCTAssertEqual(headers["attribution_sdk_ver"], "5.4.0")
    }

    func testRequestContextCanBeReusedForNativeAndWebView() {
        let provider = makeContextProvider()
        let session = RequestSession(token: "token", userID: "user")

        let nativeHeaders = provider.headers(session: session)
        let webViewHeaders = provider.headers(session: session)

        XCTAssertEqual(nativeHeaders, webViewHeaders)
    }

    func testRequestContextBuildsOAuthRiskParameters() {
        let provider = makeContextProvider()

        let parameters = provider.riskParameters(
            session: RequestSession(token: "token", userID: "user-42")
        )

        XCTAssertEqual(parameters, [
            "platform": "iOS",
            "pkg": "test.duckegg.ios",
            "ver": "2.3.4",
            "platform_ver": "17.5",
            "model": "iPhone15,2",
            "user_id": "user-42",
            "device_id": "device-123",
            "system_language": "zh_TW",
            "time_zone": "Asia/Taipei",
        ])
    }

    func testURLSessionTransportPassesRequestAndReturnsSuccessfulResponse() async throws {
        let recorder = RequestRecorder()
        let expectedURL = URL(string: "https://api.example.com/config")!
        let transport = URLSessionTransport { request in
            await recorder.record(request)
            return (
                Data("response".utf8),
                HTTPURLResponse(
                    url: expectedURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        }
        var request = URLRequest(url: expectedURL)
        request.httpMethod = "POST"

        let result = try await transport.send(request)
        let recordedRequest = await recorder.snapshot()

        XCTAssertEqual(result.data, Data("response".utf8))
        XCTAssertEqual(result.response.statusCode, 200)
        XCTAssertEqual(recordedRequest?.url, expectedURL)
        XCTAssertEqual(recordedRequest?.httpMethod, "POST")
    }

    func testURLSessionTransportMapsHTTPStatus() async {
        let url = URL(string: "https://api.example.com/config")!
        let transport = URLSessionTransport { _ in
            (
                Data("failure".utf8),
                HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
            )
        }

        await assertThrows(.httpStatus(503)) {
            _ = try await transport.send(URLRequest(url: url))
        }
    }

    func testURLSessionTransportRejectsEmptyResponse() async {
        let url = URL(string: "https://api.example.com/config")!
        let transport = URLSessionTransport { _ in
            (
                Data(),
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        await assertThrows(.emptyResponse) {
            _ = try await transport.send(URLRequest(url: url))
        }
    }

    func testURLSessionTransportMapsTimeoutAndOfflineErrors() async {
        for code in [URLError.timedOut, URLError.notConnectedToInternet] {
            let transport = URLSessionTransport { _ in throw URLError(code) }

            await assertThrows(.network(code)) {
                _ = try await transport.send(
                    URLRequest(url: URL(string: "https://api.example.com/config")!)
                )
            }
        }
    }

    private func assertThrows(
        _ expected: IntegrationAPIError,
        operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? IntegrationAPIError, expected, file: file, line: line)
        }
    }

    private func makeContextProvider(
        riskAreaCode: String? = nil,
        attributionSDK: String = "AJ",
        adjustSDKVersion: String = "5.4.0"
    ) -> RequestContextProvider {
        RequestContextProvider(
            values: RequestContextValues(
                deviceID: "device-123",
                model: "iPhone15,2",
                language: "zh",
                appVersion: "2.3.4",
                bundleIdentifier: "test.duckegg.ios",
                timeZone: "Asia/Taipei",
                country: "TW",
                platformVersion: "17.5",
                localeIdentifier: "zh_TW",
                riskAreaCode: riskAreaCode,
                attributionSDK: attributionSDK,
                adjustSDKVersion: adjustSDKVersion
            )
        )
    }

    private func makeClient(
        host: URL = URL(string: "https://test-app.bigegg.work")!,
        transport: some HTTPTransport,
        keyStore: IntegrationKeyStore,
        sleeper: @escaping IntegrationAPIClient.Sleeper = { }
    ) -> IntegrationAPIClient {
        IntegrationAPIClient(
            primaryHost: host,
            transport: transport,
            contextProvider: makeContextProvider(),
            keyStore: keyStore,
            sleeper: sleeper
        )
    }

    private func encryptedResponse(
        _ object: [String: Any],
        key: String,
        url: URL
    ) throws -> HTTPTransportResponse {
        let body = try IntegrationCipher.encryptJSONObject(object, key: key)
        return HTTPTransportResponse(
            data: Data(body.utf8),
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
    }
}

private actor RequestRecorder {
    private(set) var request: URLRequest?

    func record(_ request: URLRequest) {
        self.request = request
    }

    func snapshot() -> URLRequest? {
        request
    }
}

private actor ScriptedTransport: HTTPTransport {
    private var results: [Result<HTTPTransportResponse, Error>]
    private var recordedRequests: [URLRequest] = []

    init(results: [Result<HTTPTransportResponse, Error>]) {
        self.results = results
    }

    func send(_ request: URLRequest) async throws -> HTTPTransportResponse {
        recordedRequests.append(request)
        guard !results.isEmpty else {
            throw IntegrationAPIError.invalidResponse
        }
        return try results.removeFirst().get()
    }

    func requests() -> [URLRequest] {
        recordedRequests
    }
}

private actor SleepRecorder {
    private var value = 0

    func record() {
        value += 1
    }

    func count() -> Int {
        value
    }
}
