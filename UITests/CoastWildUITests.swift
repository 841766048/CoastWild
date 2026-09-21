import XCTest

final class CoastWildUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }
  func testOnboardingAndLoginGate() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login"]
    app.launch()
    XCTAssertTrue(app.buttons["auth.remote.submit"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.tabBars.firstMatch.exists)
    capture("00-Onboarding", app: app)
    XCTAssertFalse(app.textFields["auth.email"].exists)
    XCTAssertFalse(app.secureTextFields["auth.password"].exists)
    app.buttons["auth.remote.submit"].tap()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
  }

  func testRegisteredUserCanCreateTripAndJournalThenLogOut() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login"]
    app.launch()
    tap(app.buttons["auth.remote.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    capture("01-Explore", app: app)
    app.tabBars.buttons["学习"].tap()
    capture("05-Learn", app: app)
    app.tabBars.buttons["出游"].tap()
    capture("06-TripsEmpty", app: app)
    tap(app.buttons["创建出游"].firstMatch, in: app)
    let tripName = app.textFields["trip.name"]
    XCTAssertTrue(tripName.waitForExistence(timeout: 5))
    XCTAssertTrue(app.images["trip.cover.preview"].exists)
    XCTAssertTrue(app.buttons["trip.cover.add"].exists)
    XCTAssertTrue(app.staticTexts["未添加时使用默认封面"].exists)
    XCTAssertFalse(app.buttons["trip.cover.remove"].exists)
    capture("07-TripEditor", app: app)
    tripName.tap()
    tripName.typeText("Coastal Weekend")
    let startDate = app.buttons["trip.start"]
    XCTAssertTrue(startDate.waitForExistence(timeout: 3))
    tap(startDate, in: app)
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    XCTAssertFalse(app.keyboards.firstMatch.exists)
    app.buttons["取消"].firstMatch.tap()
    XCTAssertEqual(startDate.value as? String, "")
    tap(startDate, in: app)
    app.buttons["确定"].tap()
    let selectedStart = startDate.value as? String ?? ""
    XCTAssertNotNil(selectedStart.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression))
    tap(app.buttons["trip.end"], in: app)
    app.buttons["确定"].tap()
    XCTAssertEqual(app.buttons["trip.end"].value as? String, selectedStart)
    tap(startDate, in: app)
    app.buttons["清空"].tap()
    XCTAssertEqual(startDate.value as? String, "")
    tap(startDate, in: app)
    app.buttons["确定"].tap()
    tap(app.buttons["trip.save"], in: app)
    XCTAssertTrue(app.staticTexts["Coastal Weekend"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.images["trip.cover.detail"].exists)
    tap(app.buttons["添加体验"], in: app)
    app.buttons["第 1 天"].tap()
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    capture("25-ActivityDatePicker", app: app)
    app.buttons["确定"].tap()
    app.buttons["trip.time"].tap()
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    XCTAssertEqual(app.pickerWheels.count, 2)
    app.buttons["确定"].tap()
    XCTAssertNotNil((app.buttons["trip.time"].value as? String ?? "").range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression))
    tap(app.buttons["trip.activity.shoreline"], in: app)
    tap(app.buttons["加入出游"], in: app)
    XCTAssertTrue(app.staticTexts["海岸步道"].waitForExistence(timeout: 5))
    capture("02-Trip", app: app)
    tap(app.buttons["写一篇手记"], in: app)
    let title = app.textFields["journal.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    capture("08-JournalEditor", app: app)
    app.buttons["journal.date"].tap()
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["清空"].exists)
    capture("23-DatePicker", app: app)
    app.buttons["确定"].tap()
    title.tap()
    title.typeText("Sea Notes")
    dismissKeyboard(app)
    let body = app.textViews["journal.body"]
    tap(body, in: app)
    body.typeText("A quiet walk beside the sea.")
    dismissKeyboard(app)
    tap(app.buttons["journal.link.trip"], in: app)
    app.sheets["关联出游"].buttons["关联体验…"].tap()
    let experienceSheet = app.sheets["关联体验"]
    XCTAssertTrue(experienceSheet.waitForExistence(timeout: 5))
    let experience = experienceSheet.buttons["海岸步道"]
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: experience)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    experience.tap()
    XCTAssertTrue(app.buttons["journal.link.activity"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["journal.link.activity"].label.contains("海岸步道"))
    capture("21-JournalLink", app: app)
    app.navigationBars.buttons["保存"].tap()
    XCTAssertTrue(app.staticTexts["Coastal Weekend"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let tripCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Coastal Weekend")).firstMatch
    XCTAssertTrue(tripCard.waitForExistence(timeout: 5))
    XCTAssertEqual(tripCard.value as? String, "默认封面")
    capture("26-TripsCoverList", app: app)
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
    XCTAssertTrue(app.buttons["auth.remote.submit"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.tabBars.firstMatch.exists)
    capture("04-Login", app: app)
    tap(app.buttons["auth.remote.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    app.tabBars.buttons["出游"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Coastal Weekend")).firstMatch
        .waitForExistence(timeout: 5))
  }
  func testPersistedRemoteSessionAutomaticallyLogsInOnRelaunch() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login"]
    app.launch()
    tap(app.buttons["auth.remote.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["auth.remote.submit"].exists)
  }

  private func dismissKeyboard(_ app: XCUIApplication) {
    let done = app.toolbars.buttons.matching(NSPredicate(format: "label IN %@", ["完成", "Done"])).firstMatch
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
    // Record the settled navigation frame, not an in-flight UIKit transition.
    Thread.sleep(forTimeInterval: 0.5)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
