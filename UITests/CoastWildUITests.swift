import XCTest

final class CoastWildUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }
  func testBusinessWebHidesNavigationBarWhenItAppears() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data",
                           "--ui-testing-business-web-navigation"]
    app.launch()
    XCTAssertTrue(app.webViews["business-web.main"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.navigationBars.firstMatch.exists)
  }
  func testBusinessWebHidesNavigationBarInCoastNavigationController() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data",
                           "--ui-testing-business-web-coast-navigation"]
    app.launch()
    XCTAssertTrue(app.webViews["business-web.main"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.navigationBars.firstMatch.exists)
  }
  func testFreshInstallationRequiresPrivacyConsentBeforeLogin() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login"]
    app.launch()

    XCTAssertTrue(app.staticTexts["Welcome to Coast & Wild"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["privacy.continue"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["privacy.checkbox"].exists)
    XCTAssertTrue(app.textViews["privacy.agreement"].exists)
    XCTAssertTrue(app.buttons["privacy.decline"].exists)
    XCTAssertFalse(app.buttons["auth.remote.submit"].exists)
    XCTAssertFalse(app.tabBars.firstMatch.exists)
    XCTAssertEqual(app.links.count, 2)
    app.links.element(boundBy: 0).tap()
    XCTAssertTrue(app.webViews["legal.webview"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(app.buttons["privacy.continue"].waitForExistence(timeout: 5))
    app.buttons["privacy.continue"].tap()
    XCTAssertTrue(app.staticTexts["privacy.validation"].exists)
    app.buttons["privacy.decline"].tap()
    XCTAssertTrue(app.buttons["privacy.sheet.policy"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["privacy.sheet.accept"].exists)
    app.buttons["privacy.sheet.exit"].tap()
    XCTAssertTrue(app.buttons["privacy.continue"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["auth.remote.submit"].exists)
  }

  func testOnboardingAndLoginGate() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login"]
    app.launch()
    acceptPrivacyConsent(in: app)
    XCTAssertTrue(app.buttons["auth.remote.submit"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["auth.terms"].exists)
    XCTAssertTrue(app.buttons["auth.privacy"].exists)
    XCTAssertFalse(app.tabBars.firstMatch.exists)
    capture("00-Onboarding", app: app)
    XCTAssertFalse(app.textFields["auth.email"].exists)
    XCTAssertFalse(app.secureTextFields["auth.password"].exists)
    app.buttons["auth.remote.submit"].tap()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
  }

  func testRapidTabsPushPopAndDialogRemainStable() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--accept-privacy", "--language-zh", "--seed-account"]
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))

    for title in ["Learn", "Trips", "Journal", "Explore", "Trips", "Explore"] {
      app.tabBars.buttons[title].tap()
    }
    XCTAssertTrue(app.buttons["Your space"].waitForExistence(timeout: 5))
    app.buttons["Your space"].tap()
    XCTAssertTrue(app.navigationBars["Your space"].waitForExistence(timeout: 5))
    let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
    let cancelledDestination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.5))
    edge.press(
      forDuration: 0.05, thenDragTo: cancelledDestination,
      withVelocity: .slow, thenHoldForDuration: 0)
    XCTAssertTrue(app.navigationBars["Your space"].waitForExistence(timeout: 5))

    let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.5))
    edge.press(forDuration: 0.05, thenDragTo: destination)
    XCTAssertTrue(app.buttons["Your space"].waitForExistence(timeout: 5))

    app.buttons["Your space"].tap()
    tap(app.buttons["Data & privacy"], in: app)
    XCTAssertTrue(app.staticTexts["Your memories belong to you."].waitForExistence(timeout: 5))
    tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Photo access")).firstMatch, in: app)
    XCTAssertTrue(app.staticTexts["Only the photos you choose"].waitForExistence(timeout: 5))
    app.buttons["OK"].tap()
    XCTAssertFalse(app.staticTexts["Only the photos you choose"].exists)
  }

  func testLearningLibraryLoadsWebAndNativeDetails() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--accept-privacy", "--language-zh", "--seed-account", "--show-learning-loading"]
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
    app.tabBars.buttons["Learn"].tap()
    app.buttons["coins.free-library"].tap()
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
    XCTAssertTrue(app.navigationBars["Seven things before your first surf"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Remember these three things"].waitForExistence(timeout: 5))
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
    XCTAssertTrue(app.navigationBars["Meet your surfboard"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Next step"].waitForExistence(timeout: 5))
    shareProducesAnImage(in: app, name: "44-LearningShareNative")
    app.navigationBars.buttons.firstMatch.tap()
    XCTAssertTrue(nativeLesson.waitForExistence(timeout: 1))
    XCTAssertTrue(nativeLesson.isHittable, "Returning must preserve the learning list scroll position")
    XCTAssertFalse(app.descendants(matching: .any)["learn.loading"].exists)
  }

  func testRegisteredUserCanCreateTripAndJournalThenLogOut() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login", "--language-zh"]
    app.launch()
    acceptPrivacyConsent(in: app)
    tap(app.buttons["auth.remote.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    capture("01-Explore", app: app)
    app.tabBars.buttons["Learn"].tap()
    capture("05-Learn", app: app)
    app.tabBars.buttons["Trips"].tap()
    capture("06-TripsEmpty", app: app)
    tap(app.buttons["Create a trip"].firstMatch, in: app)
    let tripName = app.textFields["trip.name"]
    XCTAssertTrue(tripName.waitForExistence(timeout: 5))
    XCTAssertTrue(app.images["trip.cover.preview"].exists)
    XCTAssertTrue(app.buttons["trip.cover.add"].exists)
    XCTAssertTrue(app.staticTexts["The default cover is used when none is added."].exists)
    XCTAssertFalse(app.buttons["trip.cover.remove"].exists)
    capture("07-TripEditor", app: app)
    tripName.tap()
    tripName.typeText("Coastal Weekend")
    let startDate = app.buttons["trip.start"]
    XCTAssertTrue(startDate.waitForExistence(timeout: 3))
    tap(startDate, in: app)
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    XCTAssertFalse(app.keyboards.firstMatch.exists)
    app.buttons["Cancel"].firstMatch.tap()
    XCTAssertEqual(startDate.value as? String, "")
    tap(startDate, in: app)
    app.buttons["Confirm"].tap()
    let selectedStart = startDate.value as? String ?? ""
    XCTAssertNotNil(selectedStart.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression))
    tap(app.buttons["trip.end"], in: app)
    app.buttons["Confirm"].tap()
    XCTAssertEqual(app.buttons["trip.end"].value as? String, selectedStart)
    tap(startDate, in: app)
    app.buttons["Clear"].tap()
    XCTAssertEqual(startDate.value as? String, "")
    tap(startDate, in: app)
    app.buttons["Confirm"].tap()
    tap(app.buttons["trip.save"], in: app)
    XCTAssertTrue(app.staticTexts["Coastal Weekend"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.images["trip.cover.detail"].exists)
    tap(app.buttons["Add experience"], in: app)
    app.buttons["Day 1"].tap()
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    capture("25-ActivityDatePicker", app: app)
    app.buttons["Confirm"].tap()
    app.buttons["trip.time"].tap()
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    XCTAssertEqual(app.pickerWheels.count, 2)
    app.buttons["Confirm"].tap()
    XCTAssertNotNil((app.buttons["trip.time"].value as? String ?? "").range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression))
    tap(app.buttons["trip.activity.shoreline"], in: app)
    tap(app.buttons["Add to a trip"], in: app)
    XCTAssertTrue(app.staticTexts["Shoreline walk"].waitForExistence(timeout: 5))
    capture("02-Trip", app: app)
    tap(app.buttons["Write an entry"], in: app)
    let title = app.textFields["journal.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    capture("08-JournalEditor", app: app)
    app.buttons["journal.date"].tap()
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["Clear"].exists)
    capture("23-DatePicker", app: app)
    app.buttons["Confirm"].tap()
    title.tap()
    title.typeText("Sea Notes")
    dismissKeyboard(app)
    let body = app.textViews["journal.body"]
    tap(body, in: app)
    body.typeText("A quiet walk beside the sea.")
    dismissKeyboard(app)
    tap(app.buttons["journal.link.trip"], in: app)
    app.sheets["Link a trip"].buttons["Link experience…"].tap()
    let experienceSheet = app.sheets["Link experience"]
    XCTAssertTrue(experienceSheet.waitForExistence(timeout: 5))
    let experience = experienceSheet.buttons["Shoreline walk"]
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: experience)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    experience.tap()
    XCTAssertTrue(app.buttons["journal.link.activity"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["journal.link.activity"].label.contains("Shoreline walk"))
    capture("21-JournalLink", app: app)
    app.navigationBars.buttons["Save"].tap()
    XCTAssertTrue(app.staticTexts["Coastal Weekend"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let tripCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Coastal Weekend")).firstMatch
    XCTAssertTrue(tripCard.waitForExistence(timeout: 5))
    XCTAssertEqual(tripCard.value as? String, "Default cover")
    capture("26-TripsCoverList", app: app)
    app.tabBars.buttons["Journal"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sea Notes")).firstMatch
        .waitForExistence(timeout: 5))
    capture("03-Journal", app: app)
    tap(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sea Notes")).firstMatch,
      in: app)
    app.navigationBars.buttons["More"].tap()
    app.buttons["Edit"].tap()
    let editBody = app.textViews["journal.body"]
    tap(editBody, in: app)
    editBody.typeText(" Draft-only change.")
    dismissKeyboard(app)
    app.navigationBars.buttons["Cancel"].tap()
    app.buttons["Keep draft"].tap()
    XCTAssertTrue(app.staticTexts["A quiet walk beside the sea."].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["A quiet walk beside the sea. Draft-only change."].exists)
    app.navigationBars.buttons.element(boundBy: 0).tap()

    app.tabBars.buttons["Explore"].tap()
    app.buttons["Your space"].tap()
    capture("09-Profile", app: app)
    tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "My account")).firstMatch, in: app)
    tap(app.buttons["Log out"], in: app)
    XCTAssertTrue(app.buttons["auth.remote.submit"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.tabBars.firstMatch.exists)
    capture("04-Login", app: app)
    tap(app.buttons["auth.remote.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    app.tabBars.buttons["Trips"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Coastal Weekend")).firstMatch
        .waitForExistence(timeout: 5))
  }
  func testPersistedRemoteSessionAutomaticallyLogsInOnRelaunch() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login"]
    app.launch()
    acceptPrivacyConsent(in: app)
    tap(app.buttons["auth.remote.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    app.terminate()
    app.launchArguments = ["--ui-testing", "--ui-testing-slow-recovery"]
    app.launch()
    XCTAssertTrue(app.otherElements["startup.recovery"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["auth.remote.submit"].exists)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["auth.remote.submit"].exists)
    XCTAssertFalse(app.buttons["privacy.continue"].exists)
  }

  func testAccountActionsAreDistinctAndDeletionFailureCanRetry() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login", "--accept-privacy", "--account-deletion-fails"]
    app.launch()
    tap(app.buttons["auth.remote.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    app.tabBars.buttons["Explore"].tap()
    tap(app.buttons["Your space"], in: app)

    XCTAssertTrue(app.buttons["profile.account"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["profile.privacy"].exists)
    app.buttons["profile.privacy"].tap()
    XCTAssertTrue(app.buttons["privacy.clear-space"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["privacy.policy"].exists)
    XCTAssertTrue(app.buttons["privacy.terms"].exists)
    app.navigationBars.buttons.firstMatch.tap()
    app.buttons["profile.account"].tap()
    XCTAssertTrue(app.buttons["account.logout"].exists)
    XCTAssertTrue(app.buttons["account.delete"].exists)
    XCTAssertTrue(app.buttons["account.restore-purchases"].exists)
    app.buttons["account.restore-purchases"].tap()
    XCTAssertTrue(app.staticTexts["Restore complete"].waitForExistence(timeout: 5))
    app.buttons["OK"].tap()
    app.buttons["account.delete"].tap()
    XCTAssertTrue(app.staticTexts["Delete account permanently?"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Apple subscription")).firstMatch.exists)
    app.buttons["Confirm"].tap()
    XCTAssertTrue(app.staticTexts["Account deletion failed"].waitForExistence(timeout: 5))
    app.buttons["OK"].tap()
    XCTAssertTrue(app.buttons["account.delete"].isEnabled)
    XCTAssertTrue(app.buttons["account.logout"].exists)
  }

  func testSuccessfulAccountDeletionReturnsToLogin() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--ui-testing-manual-login", "--accept-privacy"]
    app.launch()
    tap(app.buttons["auth.remote.submit"], in: app)
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    app.tabBars.buttons["Explore"].tap()
    tap(app.buttons["Your space"], in: app)
    app.buttons["profile.account"].tap()
    app.buttons["account.delete"].tap()
    app.buttons["Confirm"].tap()
    XCTAssertTrue(app.buttons["auth.remote.submit"].waitForExistence(timeout: 8))
    XCTAssertFalse(app.tabBars.firstMatch.exists)
  }

  private func acceptPrivacyConsent(in app: XCUIApplication) {
    let checkbox = app.buttons["privacy.checkbox"]
    XCTAssertTrue(checkbox.waitForExistence(timeout: 10))
    checkbox.tap()
    app.buttons["privacy.continue"].tap()
    XCTAssertTrue(app.buttons["auth.remote.submit"].waitForExistence(timeout: 10))
  }

  private func dismissKeyboard(_ app: XCUIApplication) {
    let done = app.toolbars.buttons.matching(NSPredicate(format: "label == %@", "Done")).firstMatch
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
    XCTAssertFalse(app.alerts["Couldn’t create the image"].exists)
    capture(name, app: app)
    // 关掉面板，后面的返回操作才能点到导航栏。
    if sheet.buttons["header.closeButton"].exists {
      sheet.buttons["header.closeButton"].tap()
    } else {
      // iOS 26 presents this as an anchored popover, without the old close button.
      let dismissRegion = app.otherElements["PopoverDismissRegion"]
      XCTAssertTrue(dismissRegion.exists)
      dismissRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
    }
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
