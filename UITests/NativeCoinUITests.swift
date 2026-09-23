import XCTest

final class NativeCoinUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  private func launch(_ extra: [String] = [], reset: Bool = true) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--accept-privacy", "--seed-account", "--native-coins-test"]
      + (reset ? ["--reset-test-data"] : []) + extra
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Learn"].waitForExistence(timeout: 15))
    app.tabBars.buttons["Learn"].tap()
    return app
  }

  func testPurchaseUnlockReadAndPersist() {
    let app = launch()
    XCTAssertTrue(app.buttons["coins.guide.coastal-camping"].waitForExistence(timeout: 5))
    capture("01-learn", app)
    app.buttons["coins.guide.coastal-camping"].tap()
    capture("02-topic", app)
    app.buttons["coins.unlock"].tap()
    XCTAssertTrue(app.staticTexts["A few more coins"].waitForExistence(timeout: 3))
    capture("03-insufficient", app)
    app.buttons["coins.top-up"].tap()
    XCTAssertTrue(app.buttons["coins.buy"].waitForExistence(timeout: 5))
    capture("04-purchase", app)
    app.buttons["coins.buy"].tap()
    XCTAssertTrue(app.staticTexts["Your coins are ready"].waitForExistence(timeout: 10))
    capture("05-success", app)
    app.buttons["coins.return"].tap()
    XCTAssertTrue(app.buttons["coins.unlock"].waitForExistence(timeout: 5))
    app.buttons["coins.unlock"].tap()
    XCTAssertTrue(app.buttons["coins.confirm-unlock"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["70 coins"].exists)
    capture("06-confirm-unlock", app)
    app.buttons["coins.confirm-unlock"].tap()
    XCTAssertTrue(app.staticTexts["CHAPTER 1 OF 4"].waitForExistence(timeout: 5))
    capture("07-reading", app)
    for chapter in 2...4 {
      app.buttons["coins.next-chapter"].tap()
      XCTAssertTrue(app.staticTexts["CHAPTER \(chapter) OF 4"].waitForExistence(timeout: 3))
    }
    app.buttons["coins.next-chapter"].tap()
    app.terminate()
    _ = launch(reset: false)
    app.buttons["coins.wallet"].tap()
    XCTAssertTrue(app.staticTexts["70"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["-30"].exists)
    XCTAssertTrue(app.staticTexts["+100"].exists)
    capture("08-wallet", app)
    app.buttons["coins.unlocked-guides"].tap()
    XCTAssertTrue(app.buttons["coins.guide.coastal-camping"].waitForExistence(timeout: 5))
    app.buttons["coins.guide.coastal-camping"].tap()
    XCTAssertTrue(app.staticTexts["CHAPTER 1 OF 4"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["coins.confirm-unlock"].exists)
  }

  func testCancelledPurchaseDoesNotCredit() {
    let app = launch(["--coins-cancel"])
    app.buttons["coins.wallet"].tap()
    app.buttons["coins.top-up"].tap()
    XCTAssertTrue(app.buttons["coins.buy"].waitForExistence(timeout: 5))
    app.buttons["coins.buy"].tap()
    XCTAssertTrue(app.staticTexts["Purchase cancelled"].waitForExistence(timeout: 5))
    app.buttons["OK"].tap()
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.staticTexts["0"].waitForExistence(timeout: 5))
  }

  func testFreeLearningRemainsAvailable() {
    let app = launch()
    app.buttons["coins.free-library"].tap()
    XCTAssertTrue(app.buttons["learn.lesson.first-surf-seven"].waitForExistence(timeout: 5))
  }

  func testVerificationRetryDoesNotStartAnotherPayment() {
    let app = launch(["--coins-verify-retry"])
    app.buttons["coins.wallet"].tap()
    app.buttons["coins.top-up"].tap()
    XCTAssertTrue(app.buttons["coins.buy"].waitForExistence(timeout: 5))
    app.buttons["coins.buy"].tap()
    XCTAssertTrue(app.staticTexts["Confirming your coins"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["coins.buy"].exists)
    capture("09-confirming", app)
    app.buttons["coins.retry-verification"].tap()
    XCTAssertTrue(app.staticTexts["Your coins are ready"].waitForExistence(timeout: 8))
    app.buttons["coins.return"].tap()
    XCTAssertTrue(app.staticTexts["100"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts.matching(identifier: "+100").count, 1)
  }

  func testMissingProductPriceDisablesPurchaseAndOffersRetry() {
    let app = launch(["--coins-price-fails"])
    app.buttons["coins.wallet"].tap()
    app.buttons["coins.top-up"].tap()
    XCTAssertTrue(app.buttons["coins.retry-price"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["coins.buy"].isEnabled)
  }

  func testPreviewCannotAdvanceToPaidChapter() {
    let app = launch()
    app.buttons["coins.guide.coastal-camping"].tap()
    app.buttons["coins.chapter.0"].tap()
    XCTAssertTrue(app.staticTexts["CHAPTER 1 OF 4"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["coins.next-chapter"].exists)
    app.buttons["coins.unlock"].tap()
    XCTAssertTrue(app.staticTexts["A few more coins"].waitForExistence(timeout: 3))
  }

  private func capture(_ name: String, _ app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "NativeCoins-" + name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
