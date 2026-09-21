import XCTest
@testable import CoastWildCore

final class PrivacyConsentStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PrivacyConsentStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testNewInstallationHasNotAcceptedConsent() {
        XCTAssertFalse(makeStore().isAccepted)
    }

    func testAcceptancePersistsAcrossStoreInstances() {
        makeStore().accept()

        XCTAssertTrue(makeStore().isAccepted)
    }

    func testResetRemovesAcceptance() {
        let store = makeStore()
        store.accept()
        store.reset()

        XCTAssertFalse(store.isAccepted)
    }

    func testNewPolicyVersionRequiresConsentAgain() {
        makeStore(version: 1).accept()

        XCTAssertFalse(makeStore(version: 2).isAccepted)
    }

    private func makeStore(version: Int = 1) -> PrivacyConsentStore {
        PrivacyConsentStore(defaults: defaults, key: "privacy", currentVersion: version)
    }
}
