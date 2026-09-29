import XCTest

final class EnglishNavigationUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  func testEnglishPrivacyOnChineseSystem() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login",
                           "--language-zh", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    app.launch()
    XCTAssertTrue(app.staticTexts["Welcome to Coast & Wild"].waitForExistence(timeout: 15))
    XCTAssertFalse(app.staticTexts["欢迎来到海岸与山野"].exists)
    app.links["Privacy Policy"].tap()
    XCTAssertTrue(app.webViews["legal.webview"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.navigationBars["Privacy Policy"].exists)
    XCTAssertTrue(app.navigationBars.buttons["Done"].exists)
    capture("English-Privacy", app)
    app.navigationBars.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["privacy.continue"].waitForExistence(timeout: 5))
  }

  func testEnglishPreferencesAndArrowOnlyBack() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--accept-privacy", "--seed-account",
                           "--language-zh", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Explore"].waitForExistence(timeout: 15))
    app.buttons["Your space"].tap()
    XCTAssertTrue(app.navigationBars["Your space"].waitForExistence(timeout: 5))
    assertArrowOnly(in: app)
    app.buttons["Preferences"].tap()
    XCTAssertTrue(app.staticTexts["Preferences"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["简体中文"].exists)
    XCTAssertFalse(app.staticTexts["简体中文"].exists)
    assertArrowOnly(in: app)
    capture("English-Preferences-Arrow", app)
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.navigationBars["Your space"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.buttons["Your space"].waitForExistence(timeout: 5))
  }

  private func assertArrowOnly(in app: XCUIApplication) {
    let bar = app.navigationBars.firstMatch
    XCTAssertTrue(bar.buttons.firstMatch.exists)
    // The native back button keeps its VoiceOver label, but no visible title.
    XCTAssertFalse(bar.staticTexts["Back"].exists)
    XCTAssertLessThan(bar.buttons.firstMatch.frame.width, 65)
  }

  private func capture(_ name: String, _ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
