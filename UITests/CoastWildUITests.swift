import XCTest

final class CoastWildUITests: XCTestCase {
  func testOnboardingAndLoginGate() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data"]
    app.launch()
    XCTAssertTrue(app.buttons["onboarding.login"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.tabBars.firstMatch.exists)
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
    app.tabBars.buttons["出游"].tap()
    tap(app.buttons["创建出游"].firstMatch, in: app)
    let tripName = app.textFields["trip.name"]
    XCTAssertTrue(tripName.waitForExistence(timeout: 5))
    tripName.tap()
    tripName.typeText("Coastal Weekend")
    dismissKeyboard(app)
    tap(app.buttons["保存出游"], in: app)
    XCTAssertTrue(app.staticTexts["Coastal Weekend"].waitForExistence(timeout: 5))
    capture("02-Trip", app: app)
    tap(app.buttons["写一篇手记"], in: app)
    let title = app.textFields["journal.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
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
    app.navigationBars.buttons["个人空间"].tap()
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
