import XCTest
@testable import CoastWildCore

final class IntegrationEnvironmentTests: XCTestCase {
    func testNormalizesHostsAndUsesInjectedBundleIdentifier() throws {
        let environment = try IntegrationEnvironment(
            mode: .development,
            primaryHost: "https://api.example.com/",
            webHost: "https://web.example.com/path/",
            imHost: "https://im.example.com/",
            logHost: "https://log.example.com/",
            privacyURL: "https://www.example.com/privacy",
            termsURL: "https://www.example.com/terms",
            appStoreID: "1234567890",
            bundleIdentifier: "com.example.coast"
        )

        XCTAssertEqual(environment.primaryHost.absoluteString, "https://api.example.com")
        XCTAssertEqual(environment.webHost.absoluteString, "https://web.example.com/path")
        XCTAssertEqual(environment.bundleIdentifier, "com.example.coast")
    }

    func testReleaseValidationRejectsHTTPURL() throws {
        let environment = try validEnvironment(mode: .release, primaryHost: "http://api.example.com")

        XCTAssertThrowsError(try environment.validateForRelease()) { error in
            XCTAssertEqual(error as? IntegrationEnvironment.ValidationError, .insecureURL("primaryHost"))
        }
    }

    func testReleaseValidationRejectsKnownTestHost() throws {
        let environment = try validEnvironment(
            mode: .release,
            primaryHost: "https://test-app.bigegg.work"
        )

        XCTAssertThrowsError(try environment.validateForRelease()) { error in
            XCTAssertEqual(error as? IntegrationEnvironment.ValidationError, .testValue("primaryHost"))
        }
    }

    func testReleaseValidationRejectsBlankAppStoreID() throws {
        let environment = try IntegrationEnvironment(
            mode: .release,
            primaryHost: "https://api.example.com",
            webHost: "https://web.example.com",
            imHost: "https://im.example.com",
            logHost: "https://log.example.com",
            privacyURL: "https://www.example.com/privacy",
            termsURL: "https://www.example.com/terms",
            appStoreID: " ",
            bundleIdentifier: "com.example.coast"
        )

        XCTAssertThrowsError(try environment.validateForRelease()) { error in
            XCTAssertEqual(error as? IntegrationEnvironment.ValidationError, .missingValue("appStoreID"))
        }
    }

    func testLoaderBuildsEnvironmentFromInfoDictionary() throws {
        let environment = try IntegrationEnvironmentLoader.load(
            info: [
                "CoastIntegrationMode": "development",
                "CoastPrimaryHost": "https://api.example.com/",
                "CoastWebHost": "https://web.example.com/",
                "CoastIMHost": "https://im.example.com/",
                "CoastLogHost": "https://log.example.com/",
                "CoastPrivacyURL": "https://www.example.com/privacy",
                "CoastTermsURL": "https://www.example.com/terms",
                "CoastAppStoreID": "1234567890",
                "CoastAdjustToken": "adjust-token",
                "CoastReportSubheading": " - Coast & Wild",
                "CoastReportDescription": "Outdoor learning and trip planning",
                "CoastSmallIconName": "AppSmallIcon",
                "CoastLaunchImageName": "LaunchImage",
            ],
            bundleIdentifier: "com.example.coast"
        )

        XCTAssertEqual(environment.mode, .development)
        XCTAssertEqual(environment.primaryHost.absoluteString, "https://api.example.com")
        XCTAssertEqual(environment.bundleIdentifier, "com.example.coast")
        XCTAssertEqual(environment.adjustToken, "adjust-token")
        XCTAssertEqual(environment.reportSubheading, " - Coast & Wild")
        XCTAssertEqual(environment.smallIconName, "AppSmallIcon")
    }

    func testLoaderReportsMissingKeyWithoutCreatingPartialEnvironment() {
        XCTAssertThrowsError(
            try IntegrationEnvironmentLoader.load(
                info: ["CoastIntegrationMode": "development"],
                bundleIdentifier: "com.example.coast"
            )
        ) { error in
            XCTAssertEqual(
                error as? IntegrationEnvironmentLoader.LoadError,
                .missingKey("CoastPrimaryHost")
            )
        }
    }

    func testLoaderBuildsEnvironmentFromPropertyListData() throws {
        let info: [String: Any] = [
            "CoastIntegrationMode": "development",
            "CoastPrimaryHost": "https://api.example.com",
            "CoastWebHost": "https://web.example.com",
            "CoastIMHost": "https://im.example.com",
            "CoastLogHost": "https://log.example.com",
            "CoastPrivacyURL": "https://www.example.com/privacy",
            "CoastTermsURL": "https://www.example.com/terms",
            "CoastAppStoreID": "1234567890",
            "CoastAdjustToken": "adjust-token",
            "CoastReportSubheading": " - Coast & Wild",
            "CoastReportDescription": "Outdoor learning and trip planning",
            "CoastSmallIconName": "AppSmallIcon",
            "CoastLaunchImageName": "LaunchImage",
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )

        let environment = try IntegrationEnvironmentLoader.load(
            propertyListData: data,
            bundleIdentifier: "com.example.coast"
        )

        XCTAssertEqual(environment.primaryHost.absoluteString, "https://api.example.com")
        XCTAssertEqual(environment.adjustToken, "adjust-token")
    }

    func testLoaderRejectsUnknownMode() {
        let info: [String: Any] = [
            "CoastIntegrationMode": "production",
            "CoastPrimaryHost": "https://api.example.com",
            "CoastWebHost": "https://web.example.com",
            "CoastIMHost": "https://im.example.com",
            "CoastLogHost": "https://log.example.com",
            "CoastPrivacyURL": "https://www.example.com/privacy",
            "CoastTermsURL": "https://www.example.com/terms",
            "CoastAppStoreID": "1234567890",
        ]

        XCTAssertThrowsError(
            try IntegrationEnvironmentLoader.load(
                info: info,
                bundleIdentifier: "com.example.coast"
            )
        ) { error in
            XCTAssertEqual(
                error as? IntegrationEnvironmentLoader.LoadError,
                .invalidMode("production")
            )
        }
    }

    func testDefaultEndpointPathsMatchIntegrationContract() {
        XCTAssertEqual(IntegrationEndpointPaths.default.getConfig, "/config/getAppConfigPostV2")
        XCTAssertEqual(IntegrationEndpointPaths.default.getStrategy, "/config/getStrategyPostV2")
        XCTAssertEqual(IntegrationEndpointPaths.default.oauth, "/security/oauth")
        XCTAssertEqual(IntegrationEndpointPaths.default.ascribeRecord, "/hit/ascribeRecordReqs")
    }

    private func validEnvironment(
        mode: IntegrationEnvironment.Mode,
        primaryHost: String = "https://api.example.com"
    ) throws -> IntegrationEnvironment {
        try IntegrationEnvironment(
            mode: mode,
            primaryHost: primaryHost,
            webHost: "https://web.example.com",
            imHost: "https://im.example.com",
            logHost: "https://log.example.com",
            privacyURL: "https://www.example.com/privacy",
            termsURL: "https://www.example.com/terms",
            appStoreID: "1234567890",
            bundleIdentifier: "com.example.coast",
            adjustToken: "adjust-token",
            reportSubheading: " - Coast & Wild",
            reportDescription: "Outdoor learning and trip planning",
            smallIconName: "AppSmallIcon",
            launchImageName: "LaunchImage"
        )
    }
}
