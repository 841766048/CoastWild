import XCTest

final class LegalDocumentTests: XCTestCase {
    func testBundledLegalDocumentsDiscloseImplementedAndPlannedDataFlows() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CoastWild/Resources/Legal")
        let expectations: [String: [String]] = [
            "privacy-en.html": ["remote account", "device identifier", "web content", "payment", "attribution", "retention", "delete your account", "support@coastwild.app"],
            "privacy-zh-Hans.html": ["远程账号", "设备标识", "网页内容", "支付", "归因", "保留", "注销账号", "support@coastwild.app"],
            "terms-en.html": ["simulated", "apple subscription", "delete"],
            "terms-zh-Hans.html": ["模拟", "apple 订阅", "注销"],
        ]

        for (filename, phrases) in expectations {
            let contents = try String(contentsOf: root.appendingPathComponent(filename)).lowercased()
            for phrase in phrases {
                XCTAssertTrue(contents.contains(phrase.lowercased()), "\(filename) missing \(phrase)")
            }
        }
    }
}
