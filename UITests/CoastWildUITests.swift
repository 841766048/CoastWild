import XCTest

final class CoastWildUITests: XCTestCase {
  func testOnboardingAndLoginGate() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data"]
    app.launch()
    XCTAssertTrue(app.buttons["onboarding.login"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.tabBars.firstMatch.exists)
    capture("00-Onboarding", app: app)
    app.buttons["onboarding.login"].tap()
    XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 3))
    app.buttons["auth.submit"].tap()
    XCTAssertTrue(app.staticTexts["auth.error"].exists)
    XCTAssertFalse(app.tabBars.firstMatch.exists)
  }

  func testRegisteredUserCanCreateTripAndJournalThenLogOut() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data"]
    app.launch()
    tap(app.buttons["注册账号"], in: app)
    let name = app.textFields["auth.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText("Coast Tester")
    dismissKeyboard(app)
    let email = app.textFields["auth.email"]
    email.tap()
    email.typeText("native-test@example.test")
    dismissKeyboard(app)
    let password = app.secureTextFields["auth.password"]
    password.tap()
    password.typeText("coast-test-2026")
    dismissKeyboard(app)
    let confirmation = app.secureTextFields["auth.confirmation"]
    tap(confirmation, in: app)
    confirmation.typeText("coast-test-2026")
    dismissKeyboard(app)
    tap(app.buttons["auth.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    capture("01-Explore", app: app)
    app.tabBars.buttons["学习"].tap()
    capture("05-Learn", app: app)
    app.tabBars.buttons["出游"].tap()
    capture("06-TripsEmpty", app: app)
    tap(app.buttons["创建出游"].firstMatch, in: app)
    let tripName = app.textFields["trip.name"]
    XCTAssertTrue(tripName.waitForExistence(timeout: 5))
    capture("07-TripEditor", app: app)
    tripName.tap()
    tripName.typeText("Coastal Weekend")
    dismissKeyboard(app)
    tap(app.buttons["trip.save"], in: app)
    XCTAssertTrue(app.staticTexts["Coastal Weekend"].waitForExistence(timeout: 5))
    capture("02-Trip", app: app)
    tap(app.buttons["写一篇手记"], in: app)
    let title = app.textFields["journal.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    capture("08-JournalEditor", app: app)
    title.tap()
    title.typeText("Sea Notes")
    dismissKeyboard(app)
    let body = app.textViews["journal.body"]
    tap(body, in: app)
    body.typeText("A quiet walk beside the sea.")
    dismissKeyboard(app)
    app.navigationBars.buttons["保存"].tap()
    XCTAssertTrue(app.staticTexts["Coastal Weekend"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.tabBars.buttons["手记"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sea Notes")).firstMatch
        .waitForExistence(timeout: 5))
    capture("03-Journal", app: app)
    tap(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sea Notes")).firstMatch,
      in: app)
    app.navigationBars.buttons["更多"].tap()
    app.buttons["编辑"].tap()
    let editBody = app.textViews["journal.body"]
    tap(editBody, in: app)
    editBody.typeText(" Draft-only change.")
    dismissKeyboard(app)
    app.navigationBars.buttons["取消"].tap()
    app.buttons["保留草稿"].tap()
    XCTAssertTrue(app.staticTexts["A quiet walk beside the sea."].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["A quiet walk beside the sea. Draft-only change."].exists)
    app.navigationBars.buttons.element(boundBy: 0).tap()

    app.tabBars.buttons["探索"].tap()
    app.buttons["个人空间"].tap()
    capture("09-Profile", app: app)
    tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "我的账号")).firstMatch, in: app)
    tap(app.buttons["退出登录"], in: app)
    XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.tabBars.firstMatch.exists)
    capture("04-Login", app: app)
    app.textFields["auth.email"].tap()
    app.textFields["auth.email"].typeText("native-test@example.test")
    dismissKeyboard(app)
    app.secureTextFields["auth.password"].tap()
    app.secureTextFields["auth.password"].typeText("coast-test-2026")
    dismissKeyboard(app)
    tap(app.buttons["auth.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    app.tabBars.buttons["出游"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Coastal Weekend")).firstMatch
        .waitForExistence(timeout: 5))
  }
  func testKeyboardNavigationKeepsRegistrationFieldsVisible() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data"]
    app.launch()
    tap(app.buttons["注册账号"], in: app)
    capture("10-Registration", app: app)
    let name = app.textFields["auth.name"]
    name.tap()
    name.typeText("Keyboard Tester")
    let next = app.toolbars.buttons["Next"]
    XCTAssertTrue(next.waitForExistence(timeout: 5), "IQKeyboardManager toolbar should offer field navigation")
    next.tap()
    app.textFields["auth.email"].typeText("keyboard@example.test")
    next.tap()
    app.secureTextFields["auth.password"].typeText("keyboard-test-2026")
    next.tap()
    let confirmation = app.secureTextFields["auth.confirmation"]
    confirmation.typeText("keyboard-test-2026")
    XCTAssertLessThanOrEqual(confirmation.frame.maxY, app.toolbars.firstMatch.frame.minY + 1,
      "The active confirmation field must remain above the keyboard toolbar")
    XCTAssertEqual(app.toolbars.count, 1, "The app must not add a second keyboard toolbar")
    capture("11-Keyboard", app: app)
    dismissKeyboard(app)
    XCTAssertFalse(app.keyboards.firstMatch.exists)
    XCTAssertEqual(app.textFields["auth.email"].value as? String, "keyboard@example.test")
    tap(app.buttons["auth.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
  }

  private func dismissKeyboard(_ app: XCUIApplication) {
    let done = app.toolbars.buttons["完成"]
    if done.waitForExistence(timeout: 1) { done.tap() }
  }
  private func tap(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<7 {
      if element.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(element.exists)
    element.tap()
  }
  private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
