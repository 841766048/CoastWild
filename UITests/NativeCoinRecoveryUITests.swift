import XCTest

final class NativeCoinRecoveryUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  private func launch(_ flag: String, reset: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--accept-privacy", "--seed-account", "--native-coins-test", flag]
      + (reset ? ["--reset-test-data"] : [])
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Learn"].waitForExistence(timeout: 15))
    app.tabBars.buttons["Learn"].tap()
    app.buttons["coins.wallet"].tap()
    return app
  }

  func testAlreadyCreditedUnfinishedPurchaseRecoversWithoutDuplicateCredit() {
    var app = launch("--coins-credited-unfinished-seed")
    app.buttons["coins.top-up"].tap()
    XCTAssertTrue(app.buttons["coins.buy"].waitForExistence(timeout: 5))
    app.buttons["coins.buy"].tap()
    XCTAssertTrue(app.buttons["coins.return"].waitForExistence(timeout: 5))
    // The unfinished purchase has persisted its credit; navigating back reads that wallet.
    app.buttons["coins.return"].tap()
    XCTAssertTrue(app.staticTexts["100"].waitForExistence(timeout: 8))
    app.terminate()

    app = launch("--coins-credited-unfinished-recover", reset: false)
    XCTAssertTrue(app.staticTexts["100"].waitForExistence(timeout: 5))
    app.buttons["coins.top-up"].tap()
    XCTAssertTrue(app.buttons["coins.retry-verification"].waitForExistence(timeout: 5))
    app.buttons["coins.retry-verification"].tap()
    XCTAssertTrue(app.staticTexts["Your coins are ready"].waitForExistence(timeout: 8))
    app.buttons["coins.return"].tap()
    XCTAssertTrue(app.staticTexts["100"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts.matching(identifier: "+100").count, 1)
  }

  func testTerminalRejectionExitsConfirmationAndAllowsNextPurchase() {
    let app = launch("--coins-inactive-retry")
    app.buttons["coins.top-up"].tap()
    XCTAssertTrue(app.buttons["coins.buy"].waitForExistence(timeout: 5))
    app.buttons["coins.buy"].tap()
    XCTAssertTrue(app.buttons["coins.retry-verification"].waitForExistence(timeout: 5))
    app.buttons["coins.retry-verification"].tap()
    XCTAssertTrue(app.staticTexts["Purchase unavailable"].waitForExistence(timeout: 8))
    app.buttons["OK"].tap()
    XCTAssertFalse(app.buttons["coins.retry-verification"].exists)
    XCTAssertTrue(app.buttons["coins.buy"].isEnabled)
    app.buttons["coins.buy"].tap()
    XCTAssertTrue(app.staticTexts["Your coins are ready"].waitForExistence(timeout: 8))
    app.buttons["coins.return"].tap()
    XCTAssertTrue(app.staticTexts["100"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts.matching(identifier: "+100").count, 1)
  }
}
