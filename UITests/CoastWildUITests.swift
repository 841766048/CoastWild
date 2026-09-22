import XCTest

final class CoastWildUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }
  func testFirstLaunchPrivacyGateShowsPolicyAndRequiresConsent() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data"]
    app.launch()

    let continueButton = app.buttons["privacy.continue"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["onboarding.login"].exists)
    continueButton.tap()
    XCTAssertTrue(app.staticTexts["privacy.validation"].exists)

    XCTAssertFalse(app.staticTexts["Notifications"].exists)
    app.links["Privacy Policy"].tap()
    XCTAssertTrue(app.navigationBars["Privacy Policy"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.webViews["legal.webview"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.links["Contact us"].waitForExistence(timeout: 5))
    app.navigationBars.buttons["Done"].tap()

    app.buttons["privacy.decline"].tap()
    XCTAssertTrue(app.staticTexts["Continue without agreeing?"].waitForExistence(timeout: 5))
    app.buttons["privacy.sheet.accept"].tap()
    XCTAssertTrue(app.buttons["onboarding.login"].waitForExistence(timeout: 5))
  }

  func testOnboardingAndLoginGate() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--accept-privacy", "--language-zh"]
    app.launch()
    XCTAssertTrue(app.buttons["onboarding.login"].waitForExistence(timeout: 10))
    let hero = app.images["welcome.hero"]
    XCTAssertTrue(hero.exists)
    XCTAssertLessThanOrEqual(hero.frame.minY, 1)
    XCTAssertFalse(app.tabBars.firstMatch.exists)
    capture("00-Onboarding", app: app)
    app.buttons["onboarding.login"].tap()
    XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 3))
    app.buttons["auth.submit"].tap()
    XCTAssertTrue(app.staticTexts["auth.error"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.tabBars.firstMatch.exists)
  }

  func testRapidTabsPushPopAndDialogRemainStable() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--accept-privacy", "--language-zh", "--seed-account"]
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

    for title in ["学习", "出游", "手记", "探索", "出游", "探索"] {
      app.tabBars.buttons[title].tap()
    }
    XCTAssertTrue(app.buttons["个人空间"].waitForExistence(timeout: 5))
    app.buttons["个人空间"].tap()
    XCTAssertTrue(app.navigationBars["个人空间"].waitForExistence(timeout: 5))
    let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
    let cancelledDestination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.5))
    edge.press(
      forDuration: 0.05, thenDragTo: cancelledDestination,
      withVelocity: .slow, thenHoldForDuration: 0)
    XCTAssertTrue(app.navigationBars["个人空间"].waitForExistence(timeout: 5))

    let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.5))
    edge.press(forDuration: 0.05, thenDragTo: destination)
    XCTAssertTrue(app.buttons["个人空间"].waitForExistence(timeout: 5))

    app.buttons["个人空间"].tap()
    tap(app.buttons["数据与隐私"], in: app)
    XCTAssertTrue(app.staticTexts["你的回忆，属于你。"].waitForExistence(timeout: 5))
    tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "照片访问")).firstMatch, in: app)
    XCTAssertTrue(app.staticTexts["只导入你主动选择的照片"].waitForExistence(timeout: 5))
    app.buttons["好"].tap()
    XCTAssertFalse(app.staticTexts["只导入你主动选择的照片"].exists)
  }

  func testLearningLibraryLoadsWebAndNativeDetails() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--accept-privacy", "--language-zh", "--seed-account", "--show-learning-loading"]
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
    app.tabBars.buttons["学习"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["learn.loading"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.descendants(matching: .any)["learn.loading.hero"].exists)
    XCTAssertTrue(app.descendants(matching: .any)["learn.loading.card"].exists)
    capture("40-LearningSkeletonList", app: app)

    let webLesson = app.buttons["learn.lesson.first-surf-seven"]
    XCTAssertTrue(webLesson.waitForExistence(timeout: 5))
    webLesson.tap()
    XCTAssertTrue(app.descendants(matching: .any)["learn.web.loading.hero"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.descendants(matching: .any)["learn.web.loading.highlights"].exists)
    capture("41-LearningSkeletonWeb", app: app)
    XCTAssertTrue(app.navigationBars["第一次冲浪前需要知道的 7 件事"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["先记住这三件事"].waitForExistence(timeout: 5))
    shareProducesAnImage(in: app, name: "43-LearningShareWeb")
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(webLesson.waitForExistence(timeout: 1))
    XCTAssertFalse(app.descendants(matching: .any)["learn.loading"].exists,
      "Returning from a detail must keep the loaded learning page")

    let nativeLesson = app.buttons["learn.lesson.board-basics"]
    tap(nativeLesson, in: app)
    XCTAssertTrue(app.descendants(matching: .any)["learn.detail.loading"].waitForExistence(timeout: 2))
    XCTAssertTrue(app.descendants(matching: .any)["learn.detail.loading.hero"].exists)
    XCTAssertTrue(app.descendants(matching: .any)["learn.detail.loading.callout"].exists)
    capture("42-LearningSkeletonNative", app: app)
    XCTAssertTrue(app.navigationBars["认识你的冲浪板"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["下一步"].waitForExistence(timeout: 5))
    shareProducesAnImage(in: app, name: "44-LearningShareNative")
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(nativeLesson.waitForExistence(timeout: 1))
    XCTAssertTrue(nativeLesson.isHittable, "Returning must preserve the learning list scroll position")
    XCTAssertFalse(app.descendants(matching: .any)["learn.loading"].exists)
  }

  func testRegisteredUserCanCreateTripAndJournalThenLogOut() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--accept-privacy", "--language-zh"]
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
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--accept-privacy", "--language-zh"]
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
    app.buttons["个人空间"].tap()
    tap(app.buttons["偏好设置"], in: app)
    capture("12-Preferences", app: app)
    app.buttons["简体中文"].tap()
    app.buttons["English"].tap()
    XCTAssertTrue(app.tabBars.buttons["Explore"].waitForExistence(timeout: 5))
    capture("13-EnglishExplore", app: app)
    app.buttons["explore.search"].tap()
    capture("14-EnglishSearch", app: app)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.tabBars.buttons["Learn"].tap()
    capture("15-EnglishLearn", app: app)
    tap(app.buttons["learn.lesson.first-surf-seven"], in: app)
    XCTAssertTrue(app.navigationBars["Seven things before your first surf"].waitForExistence(timeout: 5))
    capture("16-EnglishLesson", app: app)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.tabBars.buttons["Explore"].tap()
    app.tabBars.buttons["Trips"].tap()
    tap(app.buttons["Create trip"].firstMatch, in: app)
    app.buttons["trip.start"].tap()
    XCTAssertTrue(app.buttons["Confirm"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["Clear"].exists)
    capture("24-EnglishDatePicker", app: app)
    app.buttons["Cancel"].firstMatch.tap()
    app.navigationBars.buttons["Cancel"].tap()
    app.tabBars.buttons["Explore"].tap()
    app.buttons["Your space"].tap()
    tap(app.buttons["Data & privacy"], in: app)
    capture("17-EnglishPrivacy", app: app)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    tap(app.buttons["My account"], in: app)
    capture("18-EnglishAccount", app: app)
    tap(app.buttons["Log out"], in: app)
    capture("19-EnglishLogin", app: app)
    tap(app.buttons["Forgot password?"], in: app)
    capture("20-EnglishRecovery", app: app)
    app.textFields["auth.email"].tap()
    app.textFields["auth.email"].typeText("keyboard@example.test")
    dismissKeyboard(app)
    tap(app.buttons["auth.submit"], in: app)
    XCTAssertTrue(app.staticTexts["auth.recovery.email"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["auth.recovery.email"].label, "keyboard@example.test")
    capture("22-EnglishReset", app: app)
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
  /// 分享按钮必须出图。出图失败时详情页会弹「无法生成图片」，
  /// 所以只要系统分享面板起来了、告警没出现，就说明截图这一步成功了。
  private func shareProducesAnImage(in app: XCUIApplication, name: String) {
    let share = app.buttons["learn.share"]
    XCTAssertTrue(share.waitForExistence(timeout: 5), "详情页应提供分享入口")
    share.tap()
    let sheet = app.otherElements["ActivityListView"]
    XCTAssertTrue(sheet.waitForExistence(timeout: 20), "分享应打开系统面板而不是失败告警")
    XCTAssertFalse(app.alerts["无法生成图片"].exists)
    capture(name, app: app)
    // 关掉面板，后面的返回操作才能点到导航栏。
    sheet.buttons["header.closeButton"].tap()
    XCTAssertTrue(sheet.waitForNonExistence(timeout: 10))
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
