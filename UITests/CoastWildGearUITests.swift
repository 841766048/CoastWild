import XCTest

/// HF-v1.3 新增功能的原生流程：装备清单、清单模板、提醒设置、足迹、手记标签与日历。
final class CoastWildGearUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testChecklistTemplateTagsTrailAndReminders() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-test-data", "--accept-privacy", "--language-zh", "--seed-account"]
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "种子账号应直接进入业务页")

    // MARK: 建一次出游，供清单与统计使用
    app.tabBars.buttons["Trips"].tap()
    tap(app.buttons["Create a trip"].firstMatch, in: app)
    let tripName = app.textFields["trip.name"]
    XCTAssertTrue(tripName.waitForExistence(timeout: 5))
    tripName.tap()
    tripName.typeText("屿角海岸三日")
    dismissKeyboard(app)
    tap(app.buttons["trip.start"], in: app)
    app.buttons["Confirm"].tap()
    tap(app.buttons["trip.end"], in: app)
    app.buttons["Confirm"].tap()
    tap(app.buttons["trip.save"], in: app)
    XCTAssertTrue(app.staticTexts["屿角海岸三日"].waitForExistence(timeout: 5))

    // MARK: TR05 空态 → TR06 套用模板
    tap(app.buttons.matching(identifier: "Packing list, Not started").firstMatch, in: app)
    XCTAssertTrue(app.navigationBars["Packing list"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Nothing packed yet"].exists)
    capture("30-GearEmpty", app: app)
    tap(app.buttons["Use a template"].firstMatch, in: app)
    XCTAssertTrue(app.navigationBars["Checklist templates"].waitForExistence(timeout: 5))
    let surf = app.buttons["gear.template.surf-weekend"]
    XCTAssertTrue(surf.waitForExistence(timeout: 3))
    // 空清单时三套模板的可补充数就是各自的物品数。
    XCTAssertTrue(surf.label.contains("12 to add"))
    let apply = app.buttons["gear.apply"]
    XCTAssertFalse(apply.isEnabled, "未选模板时不能套用")
    surf.tap()
    XCTAssertTrue(apply.isEnabled)
    capture("31-GearTemplates", app: app)
    tap(apply, in: app)

    // MARK: 勾选与进度
    XCTAssertTrue(app.navigationBars["Packing list"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["0 of 12 packed"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Surf"].exists)
    XCTAssertTrue(app.staticTexts["General"].exists)
    capture("32-GearList", app: app)
    let firstTick = app.buttons.matching(identifier: "gear.toggle").firstMatch
    XCTAssertTrue(firstTick.waitForExistence(timeout: 3))
    firstTick.tap()
    XCTAssertTrue(app.staticTexts["1 of 12 packed"].waitForExistence(timeout: 3))
    firstTick.tap()
    XCTAssertTrue(app.staticTexts["0 of 12 packed"].waitForExistence(timeout: 3))
    firstTick.tap()
    XCTAssertTrue(app.staticTexts["1 of 12 packed"].waitForExistence(timeout: 3))

    // MARK: 再次套用同一模板不重复补充
    tap(app.buttons["gear.options"], in: app)
    XCTAssertTrue(app.buttons["Use a template"].waitForExistence(timeout: 3))
    app.buttons["Use a template"].tap()
    XCTAssertTrue(app.navigationBars["Checklist templates"].waitForExistence(timeout: 5))
    let surfAgain = app.buttons["gear.template.surf-weekend"]
    XCTAssertTrue(surfAgain.waitForExistence(timeout: 3))
    XCTAssertTrue(surfAgain.label.contains("Already covered"), "已套用的模板显示已全部具备")
    surfAgain.tap()
    tap(app.buttons["gear.apply"], in: app)
    // 一项都不加时留在模板页并给出说明。
    XCTAssertTrue(app.staticTexts["Already covered"].waitForExistence(timeout: 5))
    app.buttons["OK"].tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.staticTexts["1 of 12 packed"].waitForExistence(timeout: 5), "勾选状态未被模板改动")

    // MARK: 手工添加与去重
    tap(app.buttons["gear.add"], in: app)
    let gearTitle = app.textFields["gear.title"]
    XCTAssertTrue(gearTitle.waitForExistence(timeout: 5))
    gearTitle.tap()
    gearTitle.typeText("Dry bag")
    dismissKeyboard(app)
    tap(app.buttons["gear.save"], in: app)
    XCTAssertTrue(app.staticTexts["1 of 13 packed"].waitForExistence(timeout: 5))
    tap(app.buttons["gear.add"], in: app)
    let again = app.textFields["gear.title"]
    XCTAssertTrue(again.waitForExistence(timeout: 5))
    again.tap()
    again.typeText(" dry BAG ")
    dismissKeyboard(app)
    tap(app.buttons["gear.save"], in: app)
    XCTAssertTrue(app.staticTexts["This item is already in that group."].waitForExistence(timeout: 5))
    app.buttons["OK"].tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.staticTexts["1 of 13 packed"].waitForExistence(timeout: 5))

    // MARK: 回到出游详情确认进度同步
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(
      app.buttons.matching(identifier: "Packing list, 1 of 13 packed").firstMatch.waitForExistence(
        timeout: 5))

    // MARK: JO02 标签
    popToRoot(app)
    app.tabBars.buttons["Journal"].tap()
    tap(app.buttons["New entry"].firstMatch, in: app)
    let body = app.textViews["journal.body"]
    XCTAssertTrue(body.waitForExistence(timeout: 5))
    body.tap()
    body.typeText("浪小但水很清。")
    dismissKeyboard(app)
    tap(app.buttons["journal.tag.add"], in: app)
    let tagInput = app.textFields["journal.tag.input"]
    XCTAssertTrue(tagInput.waitForExistence(timeout: 5))
    tagInput.tap()
    tagInput.typeText("晨浪")
    XCTAssertEqual(tagInput.value as? String, "晨浪", "标签输入框应收到完整文字")
    app.buttons["Add"].tap()
    XCTAssertTrue(app.staticTexts["晨浪"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["1 / 5"].exists)
    // 重复标签被拒，计数不变。
    tap(app.buttons["journal.tag.add"], in: app)
    let duplicate = app.textFields["journal.tag.input"]
    XCTAssertTrue(duplicate.waitForExistence(timeout: 5))
    duplicate.tap()
    duplicate.typeText("晨浪")
    app.buttons["Add"].tap()
    XCTAssertTrue(app.staticTexts["That tag is already on this entry."].waitForExistence(timeout: 3))
    app.buttons["OK"].tap()
    XCTAssertTrue(app.staticTexts["1 / 5"].exists)
    capture("33-JournalTags", app: app)
    tap(app.buttons["journal.save"], in: app)

    // MARK: JO04 日历
    popToRoot(app)
    app.tabBars.buttons["Journal"].tap()
    tap(app.buttons["journal.calendar"], in: app)
    XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["1 entries · 1 days"].waitForExistence(timeout: 3))
    capture("34-JournalCalendar", app: app)
    // 有手记的那天可点，点开出当天列表。
    let marked = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "1 entries")
    ).firstMatch
    XCTAssertTrue(marked.waitForExistence(timeout: 3))
    marked.tap()
    XCTAssertTrue(app.staticTexts["晨浪"].waitForExistence(timeout: 3))
    app.navigationBars.buttons.element(boundBy: 0).tap()

    // MARK: ME02 足迹
    popToRoot(app)
    app.tabBars.buttons["Explore"].tap()
    // 探索页也是根页，个人空间入口在内容里而不是导航栏。
    tap(app.buttons["Your space"].firstMatch, in: app)
    XCTAssertTrue(app.navigationBars["Your space"].waitForExistence(timeout: 5))
    tap(app.buttons.matching(identifier: "Your trail").firstMatch, in: app)
    XCTAssertTrue(app.navigationBars["Your trail"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Experience mix"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.staticTexts["Milestones"].exists)
    // 徽章整块作为一个可访问元素朗读，内部文字不单独暴露。
    let badge = app.descendants(matching: .any).matching(
      NSPredicate(format: "label CONTAINS %@", "First lesson")
    ).firstMatch
    XCTAssertTrue(badge.waitForExistence(timeout: 3))
    XCTAssertTrue(badge.label.contains("locked"), "新账号首课未完成")
    capture("35-Trail", app: app)
    app.navigationBars.buttons.element(boundBy: 0).tap()

    // MARK: SE03 提醒
    tap(app.buttons.matching(identifier: "Reminders, Off").firstMatch, in: app)
    XCTAssertTrue(app.navigationBars["Reminders"].waitForExistence(timeout: 5))
    let tripSwitch = app.switches["reminder.trip"]
    XCTAssertTrue(tripSwitch.waitForExistence(timeout: 3))
    XCTAssertEqual(tripSwitch.value as? String, "0")
    let whenRow = app.buttons["reminder.when"]
    XCTAssertFalse(whenRow.isEnabled, "未开启时提醒时间不可点")
    XCTAssertTrue(app.staticTexts["Trip reminders"].exists)
    XCTAssertTrue(app.staticTexts["System permission"].exists)
    capture("36-Reminders", app: app)
  }

  // MARK: 辅助

  /// push 的详情页会隐藏 tab bar，逐级返回直到根页。
  private func popToRoot(_ app: XCUIApplication) {
    for _ in 0..<6 {
      if app.tabBars.firstMatch.exists { return }
      let back = app.navigationBars.buttons.element(boundBy: 0)
      guard back.exists, back.isHittable else { return }
      back.tap()
      Thread.sleep(forTimeInterval: 0.4)
    }
  }

  private func dismissKeyboard(_ app: XCUIApplication) {
    let done = app.toolbars.buttons.matching(
      NSPredicate(format: "label == %@", "Done")
    ).firstMatch
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
    Thread.sleep(forTimeInterval: 0.5)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
