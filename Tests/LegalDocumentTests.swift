import XCTest

final class LegalDocumentTests: XCTestCase {
    func testBundledLegalDocumentsDiscloseImplementedAndPlannedDataFlows() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CoastWild/Resources/Legal")
        let expectations: [String: [String]] = [
            "privacy-en.html": ["remote account", "device identifier", "web content", "payment", "attribution", "retention", "delete your account", "support@coastwild.app"],
            "terms-en.html": ["simulated", "apple subscription", "delete"],
        ]

        for (filename, phrases) in expectations {
            let contents = try String(contentsOf: root.appendingPathComponent(filename)).lowercased()
            for phrase in phrases {
                XCTAssertTrue(contents.contains(phrase.lowercased()), "\(filename) missing \(phrase)")
            }
        }
    }
}
