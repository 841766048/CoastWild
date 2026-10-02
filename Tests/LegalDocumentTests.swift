import XCTest
@testable import CoastWildCore

final class LegalDocumentTests: XCTestCase {
    func testPrivacyUsesReadOnlyGoogleViewAndTermsRemainLocal() {
        let config = ["CoastPrivacyURL": "https://docs.google.com/document/d/example/edit?tab=t.0"]
        XCTAssertEqual(LegalDocument.privacy.remoteURL(language: "en", configuration: config)?.absoluteString,
                       "https://docs.google.com/document/d/example/mobilebasic")
        XCTAssertNil(LegalDocument.terms.remoteURL(language: "en", configuration: config))
        XCTAssertNil(LegalDocument.privacy.remoteURL(language: "en", configuration: ["CoastPrivacyURL": "http://example.com"]))
    }
    func testBundledLegalDocumentsDiscloseImplementedAndPlannedDataFlows() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CoastWild/Resources/Legal")
        let expectations: [String: [String]] = [
            "privacy-en.html": ["anonymous authentication", "device identifier", "web content", "retention", "delete your account", "support@coastwild.app"],
            "terms-en.html": ["authentication account", "delete", "retried"],
        ]

        for (filename, phrases) in expectations {
            let contents = try String(contentsOf: root.appendingPathComponent(filename)).lowercased()
            for phrase in phrases {
                XCTAssertTrue(contents.contains(phrase.lowercased()), "\(filename) missing \(phrase)")
            }
        }
    }
}
