import XCTest
@testable import CoastWildCore

/// HF-v1.3 新增：装备清单、手记标签、提醒设置与足迹统计。
final class CoastWildGearTests: XCTestCase {
    private var directory: URL!
    private var store: CoastStore!
    private var tripID: String!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = try CoastStore(directory: directory)
        try store.activate(accountID: "account-1")
        let trip = CoastTrip(name: "Coast weekend", start: "2026-10-10", end: "2026-10-12")
        tripID = trip.id
        try store.saveTrip(trip)
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: directory)
    }

    private func gear() -> [CoastGearItem] {
        store.ledger.trips.first { $0.id == tripID }?.gearList ?? []
    }

    private func key(_ error: Error) -> String {
        (error as? CoastStoreError)?.key ?? error.localizedDescription
    }

    private func expectKey(_ expected: String, _ body: () throws -> Void) {
        do {
            try body()
            XCTFail("expected \(expected)")
        } catch {
            XCTAssertEqual(key(error), expected)
        }
    }

    // MARK: 向后兼容

    func testLedgerWithoutNewFieldsStillDecodes() throws {
        // 模拟 HF-v1.2 写下的账本：没有 gear、没有 tags。
        let legacy = """
        {"trips":[{"id":"t1","name":"Old trip","start":"2026-05-01","end":"2026-05-02",
        "notes":"kept","timeZone":"Asia/Shanghai","completed":true,
        "items":[{"id":"i1","activityID":"shoreline","day":0,"titleSnapshot":"Shore"}]}],
        "entries":[{"id":"e1","title":"Kept","body":"Body survives.","date":"2026-05-01",
        "photos":[],"isDraft":false}],
        "bookmarks":["shoreline"],"progress":{}}
        """
        let ledger = try JSONDecoder().decode(CoastLedger.self, from: Data(legacy.utf8))
        XCTAssertEqual(ledger.trips.count, 1)
        XCTAssertNil(ledger.trips[0].gear, "旧账本没有 gear 字段")
        XCTAssertEqual(ledger.trips[0].gearList, [], "读出来是空清单而不是崩溃")
        XCTAssertEqual(ledger.trips[0].notes, "kept")
        XCTAssertEqual(ledger.trips[0].items.count, 1)
        XCTAssertNil(ledger.entries[0].tags)
        XCTAssertEqual(ledger.entries[0].tagList, [])
        XCTAssertEqual(ledger.entries[0].body, "Body survives.")
        XCTAssertEqual(ledger.bookmarks, ["shoreline"])
    }

    func testPreferencesWithoutRemindersStillDecodes() throws {
        let legacy = """
        {"language":"en","region":"US","distanceUnit":"mi","temperatureUnit":"f",
        "onboardingDone":true}
        """
        let preferences = try JSONDecoder().decode(CoastPreferences.self, from: Data(legacy.utf8))
        XCTAssertNil(preferences.reminders)
        XCTAssertEqual(preferences.language, "en")
        XCTAssertTrue(preferences.onboardingDone)
    }

    func testLedgerWithoutRemindersStillDecodes() throws {
        let legacy = """
        {"trips":[],"entries":[],"bookmarks":[],"progress":{}}
        """
        let ledger = try JSONDecoder().decode(CoastLedger.self, from: Data(legacy.utf8))
        XCTAssertNil(ledger.reminders)
        XCTAssertEqual(ledger.reminderPlan, CoastReminderPlan(), "缺失时回落到默认提醒设置")
    }

    func testStoreReadsALegacyLedgerFileFromDisk() throws {
        let other = directory.appendingPathComponent("legacy")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let legacyStore = try CoastStore(directory: other)
        try legacyStore.activate(accountID: "old-account")
        try legacyStore.saveTrip(CoastTrip(name: "Before upgrade"))
        // 把磁盘上的账本改写成不含新字段的形态，再重新打开。
        let files = try FileManager.default.contentsOfDirectory(at: other, includingPropertiesForKeys: nil)
        let ledgerURL = try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("ledger-") })
        var raw = try XCTUnwrap(String(data: Data(contentsOf: ledgerURL), encoding: .utf8))
        raw = raw.replacingOccurrences(of: "\"gear\":[]", with: "")
            .replacingOccurrences(of: ",,", with: ",")
            .replacingOccurrences(of: "{,", with: "{")
            .replacingOccurrences(of: ",}", with: "}")
        try Data(raw.utf8).write(to: ledgerURL, options: .atomic)
        let reopened = try CoastStore(directory: other)
        try reopened.activate(accountID: "old-account")
        XCTAssertEqual(reopened.ledger.trips.count, 1)
        XCTAssertEqual(reopened.ledger.trips[0].name, "Before upgrade")
        XCTAssertEqual(reopened.ledger.trips[0].gearList, [])
    }

    // MARK: 校验

    func testGearValidationMapsEveryBadShapeToAStableKey() {
        let ok = CoastGearItem(title: "Wetsuit", category: "surf")
        XCTAssertNil(CoastValidation.gearItem(ok))
        XCTAssertEqual(
            CoastValidation.gearItem(CoastGearItem(id: " ", title: "x")), "checklist.id.required")
        XCTAssertEqual(
            CoastValidation.gearItem(CoastGearItem(title: "   ")), "checklist.title.required")
        XCTAssertEqual(
            CoastValidation.gearItem(CoastGearItem(title: String(repeating: "x", count: 41))),
            "checklist.title.tooLong")
        XCTAssertNil(CoastValidation.gearItem(CoastGearItem(title: String(repeating: "x", count: 40))))
        XCTAssertEqual(
            CoastValidation.gearItem(CoastGearItem(title: "x", category: "surfing")),
            "checklist.category.invalid")
        XCTAssertEqual(
            CoastValidation.gearItem(CoastGearItem(title: "x", sortOrder: -1)),
            "checklist.order.invalid")

        // 同名不同分组允许并存。
        XCTAssertNil(
            CoastValidation.gear([
                CoastGearItem(title: "Sunscreen", category: "surf"),
                CoastGearItem(title: "Sunscreen", category: "general"),
            ]))
        XCTAssertEqual(
            CoastValidation.gear([
                CoastGearItem(title: "Wetsuit", category: "surf"),
                CoastGearItem(title: "  wetsuit  ", category: "surf"),
            ]), "checklist.duplicate")
        let many = (0..<61).map { CoastGearItem(title: "Item \($0)", sortOrder: $0) }
        XCTAssertEqual(CoastValidation.gear(many), "checklist.tooMany")
    }

    func testTagValidationEnforcesCountLengthAndUniqueness() {
        XCTAssertNil(CoastValidation.tags([]))
        XCTAssertNil(CoastValidation.tags(["morning", "longboard"]))
        XCTAssertEqual(CoastValidation.tags([" "]), "entry.tag.required")
        XCTAssertEqual(
            CoastValidation.tags([String(repeating: "x", count: 13)]), "entry.tag.tooLong")
        XCTAssertNil(CoastValidation.tags([String(repeating: "x", count: 12)]))
        XCTAssertEqual(CoastValidation.tags(["Surf", " surf "]), "entry.tag.duplicate")
        XCTAssertNil(CoastValidation.tags(["a", "b", "c", "d", "e"]))
        XCTAssertEqual(CoastValidation.tags(["a", "b", "c", "d", "e", "f"]), "entry.tags.tooMany")
    }

    func testReminderValidationCoversRangesAndClocks() {
        XCTAssertNil(CoastValidation.reminders(CoastReminderPlan()))
        XCTAssertNil(
            CoastValidation.reminders(
                CoastReminderPlan(tripLeadDays: 0, tripTime: "00:00", journalTime: "23:59")))
        XCTAssertEqual(
            CoastValidation.reminders(CoastReminderPlan(tripLeadDays: 8)), "reminder.lead.invalid")
        XCTAssertEqual(
            CoastValidation.reminders(CoastReminderPlan(tripLeadDays: -1)), "reminder.lead.invalid")
        XCTAssertEqual(
            CoastValidation.reminders(CoastReminderPlan(tripTime: "24:00")), "reminder.time.invalid")
        XCTAssertEqual(
            CoastValidation.reminders(CoastReminderPlan(journalTime: "8:00")),
            "reminder.time.invalid")
    }

    // MARK: 清单写入

    func testAddingGearTrimsTitlesAssignsOrderAndRefusesDuplicates() throws {
        try store.addGearItem(tripID: tripID, item: CoastGearItem(title: "  Head lamp  ", category: "camp"))
        XCTAssertEqual(gear().count, 1)
        XCTAssertEqual(gear()[0].title, "Head lamp")
        XCTAssertEqual(gear()[0].sortOrder, 0)
        XCTAssertFalse(gear()[0].done)
        try store.addGearItem(tripID: tripID, item: CoastGearItem(title: "Water", category: "general"))
        XCTAssertEqual(gear()[1].sortOrder, 1)
        expectKey("checklist.duplicate") {
            try self.store.addGearItem(
                tripID: self.tripID, item: CoastGearItem(title: "head  LAMP", category: "camp"))
        }
        expectKey("trip.notFound") {
            try self.store.addGearItem(tripID: "nope", item: CoastGearItem(title: "x"))
        }
    }

    func testToggleUpdateAndRemoveAffectOnlyTheAddressedItem() throws {
        try store.addGearItem(tripID: tripID, item: CoastGearItem(title: "Tent", category: "camp"))
        try store.addGearItem(tripID: tripID, item: CoastGearItem(title: "Stove", category: "camp"))
        let first = gear()[0].id
        try store.toggleGearItem(tripID: tripID, itemID: first)
        XCTAssertTrue(gear()[0].done)
        XCTAssertFalse(gear()[1].done)
        try store.updateGearItem(tripID: tripID, itemID: first, title: " Tarp ", category: "general")
        XCTAssertEqual(gear()[0].title, "Tarp")
        XCTAssertEqual(gear()[0].category, "general")
        XCTAssertTrue(gear()[0].done, "改名换组不影响勾选状态")
        try store.removeGearItem(tripID: tripID, itemID: first)
        XCTAssertEqual(gear().count, 1)
        XCTAssertEqual(gear()[0].title, "Stove")
        expectKey("checklist.notFound") {
            try self.store.toggleGearItem(tripID: self.tripID, itemID: first)
        }
        expectKey("checklist.notFound") {
            try self.store.removeGearItem(tripID: self.tripID, itemID: first)
        }
    }

    func testApplyingATemplateOnlyFillsGapsAndNeverClearsATick() throws {
        try store.addGearItem(
            tripID: tripID,
            item: CoastGearItem(sourceKey: "wetsuit", title: "Wetsuit", category: "surf"))
        try store.toggleGearItem(tripID: tripID, itemID: gear()[0].id)
        XCTAssertTrue(gear()[0].done)

        let added = try store.applyGearTemplate(
            tripID: tripID,
            items: [
                // 已有（sourceKey 相同，标题是中文）：跳过，不改勾选。
                CoastGearItem(sourceKey: "wetsuit", title: "防寒衣", category: "surf", done: true),
                // 尚未有：补进来，且一定未勾选。
                CoastGearItem(sourceKey: "leash", title: "Leash", category: "surf", done: true),
                CoastGearItem(sourceKey: "first-aid", title: "First aid kit", category: "general"),
            ])
        XCTAssertEqual(added, 2)
        XCTAssertEqual(gear().count, 3)
        XCTAssertEqual(gear().filter(\.done).map(\.title), ["Wetsuit"], "套用模板不改变任何勾选")
        XCTAssertEqual(gear().first { $0.sourceKey == "leash" }?.done, false, "补进来的一律未勾选")
        XCTAssertEqual(gear().filter { $0.sourceKey == "wetsuit" }.count, 1)
        XCTAssertEqual(gear().map(\.sortOrder), [0, 1, 2])

        // 再套用同一批：一项都不加。
        let again = try store.applyGearTemplate(
            tripID: tripID,
            items: [
                CoastGearItem(sourceKey: "wetsuit", title: "Wetsuit", category: "surf"),
                CoastGearItem(sourceKey: "leash", title: "Leash", category: "surf"),
                CoastGearItem(sourceKey: "first-aid", title: "First aid kit", category: "general"),
            ])
        XCTAssertEqual(again, 0)
        XCTAssertEqual(gear().count, 3)
    }

    func testTemplateDedupeFallsBackToTitleWithoutASourceKey() throws {
        try store.addGearItem(tripID: tripID, item: CoastGearItem(title: "Dry bag", category: "general"))
        XCTAssertNil(gear()[0].sourceKey)
        let added = try store.applyGearTemplate(
            tripID: tripID,
            items: [CoastGearItem(title: " dry BAG ", category: "general")])
        XCTAssertEqual(added, 0, "没有 sourceKey 时按标题去重")
        // 同一次套用里重复的也只进一条。
        let shared = try store.applyGearTemplate(
            tripID: tripID,
            items: [
                CoastGearItem(sourceKey: "water", title: "Drinking water", category: "general"),
                CoastGearItem(sourceKey: "water", title: "饮用水", category: "general"),
            ])
        XCTAssertEqual(shared, 1)
        expectKey("checklist.title.required") {
            _ = try self.store.applyGearTemplate(
                tripID: self.tripID, items: [CoastGearItem(title: "  ")])
        }
    }

    func testClearingTicksKeepsItemsAndClearingGearRemovesThem() throws {
        try store.applyGearTemplate(
            tripID: tripID,
            items: [
                CoastGearItem(sourceKey: "tent", title: "Tent", category: "camp"),
                CoastGearItem(sourceKey: "stove", title: "Stove", category: "camp"),
            ])
        for item in gear() { try store.toggleGearItem(tripID: tripID, itemID: item.id) }
        XCTAssertEqual(gear().filter(\.done).count, 2)
        try store.clearGearTicks(tripID: tripID)
        XCTAssertEqual(gear().count, 2, "清空勾选保留物品")
        XCTAssertEqual(gear().filter(\.done).count, 0)
        try store.clearGear(tripID: tripID)
        XCTAssertEqual(gear(), [])
    }

    func testSavingATripWithoutGearKeepsTheExistingChecklist() throws {
        try store.addGearItem(tripID: tripID, item: CoastGearItem(title: "Tent", category: "camp"))
        var form = try XCTUnwrap(store.ledger.trips.first { $0.id == tripID })
        form.name = "Renamed"
        form.gear = nil  // 出游表单不提交清单
        try store.saveTrip(form)
        XCTAssertEqual(store.ledger.trips[0].name, "Renamed")
        XCTAssertEqual(gear().map(\.title), ["Tent"], "表单不提交清单时不清空清单")

        let fresh = CoastTrip(name: "Brand new")
        try store.saveTrip(fresh)
        XCTAssertEqual(store.ledger.trips.first { $0.id == fresh.id }?.gearList, [], "新出游清单为空")

        var broken = try XCTUnwrap(store.ledger.trips.first { $0.id == tripID })
        broken.gearList = [CoastGearItem(title: "x", category: "nope")]
        expectKey("checklist.category.invalid") { try self.store.saveTrip(broken) }
    }

    func testDeletingATripTakesItsChecklistWithIt() throws {
        try store.addGearItem(tripID: tripID, item: CoastGearItem(title: "Tent", category: "camp"))
        try store.deleteTrip(id: tripID)
        XCTAssertEqual(store.ledger.trips.count, 0)
        expectKey("trip.notFound") {
            try self.store.addGearItem(tripID: self.tripID, item: CoastGearItem(title: "y"))
        }
    }

    func testChecklistSurvivesAReopenOfTheSameAccount() throws {
        try store.applyGearTemplate(
            tripID: tripID,
            items: [
                CoastGearItem(sourceKey: "tent", title: "Tent", category: "camp"),
                CoastGearItem(sourceKey: "water", title: "Drinking water", category: "general"),
            ])
        try store.toggleGearItem(tripID: tripID, itemID: gear()[0].id)
        let reopened = try CoastStore(directory: directory)
        try reopened.activate(accountID: "account-1")
        let list = try XCTUnwrap(reopened.ledger.trips.first { $0.id == tripID }).gearList
        XCTAssertEqual(list.map(\.title), ["Tent", "Drinking water"])
        XCTAssertEqual(list.map(\.done), [true, false])
        XCTAssertEqual(list.map(\.sourceKey), ["tent", "water"])
    }

    func testGearProgressAndGroupingDriveTheChecklistScreen() throws {
        try store.applyGearTemplate(
            tripID: tripID,
            items: [
                CoastGearItem(sourceKey: "surfboard", title: "Surfboard", category: "surf"),
                CoastGearItem(sourceKey: "wetsuit", title: "Wetsuit", category: "surf"),
                CoastGearItem(sourceKey: "tent", title: "Tent", category: "camp"),
                CoastGearItem(sourceKey: "water", title: "Drinking water", category: "general"),
            ])
        let trip = try XCTUnwrap(store.ledger.trips.first { $0.id == tripID })
        XCTAssertEqual(trip.gearProgress.total, 4)
        XCTAssertEqual(trip.gearProgress.done, 0)
        XCTAssertEqual(trip.gearProgress.left, 4)
        XCTAssertEqual(trip.gearProgress.ratio, 0)
        try store.toggleGearItem(tripID: tripID, itemID: trip.gearList[0].id)
        let ticked = try XCTUnwrap(store.ledger.trips.first { $0.id == tripID })
        XCTAssertEqual(ticked.gearProgress.done, 1)
        XCTAssertEqual(ticked.gearProgress.ratio, 0.25)
        // 分组顺序固定为 surf / hike / camp / general，空分组不出现。
        XCTAssertEqual(ticked.gearByCategory.map(\.category), ["surf", "camp", "general"])
        XCTAssertEqual(ticked.gearByCategory.map(\.items.count), [2, 1, 1])
        XCTAssertEqual(CoastTrip(name: "empty").gearByCategory.count, 0)
        XCTAssertEqual(CoastTrip(name: "empty").gearProgress.ratio, 0)
    }

    // MARK: 标签

    func testEntriesCarryTagsAndRejectBadOnes() throws {
        var entry = CoastEntry(date: "2026-10-12")
        entry.body = "Some words."
        entry.isDraft = false
        entry.tagList = ["sunrise", "longboard"]
        try store.saveEntry(entry)
        XCTAssertEqual(store.ledger.entries[0].tagList, ["sunrise", "longboard"])

        var duplicate = entry
        duplicate.id = UUID().uuidString
        duplicate.tagList = ["Surf", "surf"]
        expectKey("entry.tag.duplicate") { try self.store.saveEntry(duplicate) }

        var tooMany = entry
        tooMany.id = UUID().uuidString
        tooMany.tagList = ["a", "b", "c", "d", "e", "f"]
        expectKey("entry.tags.tooMany") { try self.store.saveEntry(tooMany) }

        // 草稿也受上限约束。
        var draft = entry
        draft.id = UUID().uuidString
        draft.isDraft = true
        draft.tagList = ["a", "b", "c", "d", "e", "f"]
        expectKey("entry.tags.tooMany") { try self.store.saveEntry(draft) }
    }

    func testTagIndexCountsPublishedEntriesOnlyMostUsedFirst() throws {
        for (index, tags) in [["camp", "dusk"], ["camp"], ["surf"]].enumerated() {
            var entry = CoastEntry(date: "2026-10-1\(index)")
            entry.body = "Words \(index)"
            entry.isDraft = false
            entry.tagList = tags
            try store.saveEntry(entry)
        }
        var draft = CoastEntry(date: "2026-10-20")
        draft.body = "Draft words"
        draft.isDraft = true
        draft.tagList = ["secret"]
        try store.saveEntry(draft)
        XCTAssertEqual(store.ledger.tagIndex.map(\.tag), ["camp", "dusk", "surf"])
        XCTAssertEqual(store.ledger.tagIndex.map(\.count), [2, 1, 1])
        XCTAssertFalse(store.ledger.tagIndex.contains { $0.tag == "secret" }, "草稿标签不进索引")
    }

    func testEditingAPublishedEntryKeepsTagsThroughTheDraftSwap() throws {
        var published = CoastEntry(date: "2026-10-12")
        published.body = "Original body."
        published.isDraft = false
        published.tagList = ["sunrise"]
        try store.saveEntry(published)

        var draft = published
        draft.id = UUID().uuidString
        draft.isDraft = true
        draft.sourceEntryID = published.id
        draft.body = "Edited body."
        draft.tagList = ["sunrise", "tide"]
        try store.saveEntry(draft)
        XCTAssertEqual(store.ledger.entries.count, 2, "草稿与原文并存")
        XCTAssertEqual(store.ledger.entries.first { $0.id == published.id }?.tagList, ["sunrise"])

        var final = draft
        final.isDraft = false
        try store.saveEntry(final)
        XCTAssertEqual(store.ledger.entries.count, 1, "正式保存原子替换原文")
        XCTAssertEqual(store.ledger.entries[0].id, published.id)
        XCTAssertEqual(store.ledger.entries[0].body, "Edited body.")
        XCTAssertEqual(store.ledger.entries[0].tagList, ["sunrise", "tide"])
    }

    // MARK: 提醒

    func testReminderUpdatesPersistAndValidate() throws {
        XCTAssertEqual(store.ledger.reminderPlan, CoastReminderPlan())
        var plan = store.ledger.reminderPlan
        plan.tripEnabled = true
        plan.tripLeadDays = 3
        plan.tripTime = "07:15"
        try store.updateReminders(plan)
        XCTAssertTrue(store.ledger.reminderPlan.tripEnabled)
        XCTAssertEqual(store.ledger.reminderPlan.tripLeadDays, 3)
        XCTAssertEqual(store.ledger.reminderPlan.tripTime, "07:15")

        expectKey("reminder.time.invalid") {
            try self.store.updateReminders(CoastReminderPlan(tripTime: "7:15"))
        }
        expectKey("reminder.lead.invalid") {
            try self.store.updateReminders(CoastReminderPlan(tripLeadDays: 9))
        }
        XCTAssertEqual(store.ledger.reminderPlan.tripTime, "07:15", "失败不改动已保存设置")

        let reopened = try CoastStore(directory: directory)
        try reopened.activate(accountID: "account-1")
        XCTAssertEqual(reopened.ledger.reminderPlan.tripTime, "07:15", "重开后仍在本账号名下")
    }

    func testRemindersStayWithinOneAccount() throws {
        try store.updateReminders(CoastReminderPlan(tripEnabled: true, tripLeadDays: 3))

        try store.activate(accountID: "account-2")
        XCTAssertEqual(store.ledger.reminderPlan, CoastReminderPlan(), "另一个账号从默认设置开始")
        try store.updateReminders(CoastReminderPlan(journalEnabled: true, journalTime: "21:00"))

        try store.activate(accountID: "account-1")
        XCTAssertTrue(store.ledger.reminderPlan.tripEnabled)
        XCTAssertEqual(store.ledger.reminderPlan.tripLeadDays, 3)
        XCTAssertFalse(store.ledger.reminderPlan.journalEnabled, "不受另一个账号影响")
    }

    func testReminderWritesRequireAnAccount() throws {
        try store.activate(accountID: nil)
        expectKey("account.required") {
            try self.store.updateReminders(CoastReminderPlan(tripEnabled: true))
        }
        XCTAssertEqual(store.ledger.reminderPlan, CoastReminderPlan())
    }

    /// 旧版本把提醒存在全局 preferences 里。首个登入的账号接手，随后全局字段清空。
    func testLegacyGlobalRemindersMigrateToTheFirstAccount() throws {
        let folder = directory.appendingPathComponent("legacy-migration")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let legacy = try CoastStore(directory: folder)
        var preferences = legacy.preferences
        preferences.reminders = CoastReminderPlan(tripEnabled: true, tripTime: "06:45")
        try legacy.updatePreferences(preferences)

        let migrated = try CoastStore(directory: folder)
        try migrated.activate(accountID: "account-1")
        XCTAssertTrue(migrated.ledger.reminderPlan.tripEnabled)
        XCTAssertEqual(migrated.ledger.reminderPlan.tripTime, "06:45")
        XCTAssertNil(migrated.preferences.reminders, "迁移后清空全局字段")

        try migrated.activate(accountID: "account-2")
        XCTAssertEqual(migrated.ledger.reminderPlan, CoastReminderPlan(), "不再串到其他账号")

        let reopened = try CoastStore(directory: folder)
        try reopened.activate(accountID: "account-1")
        XCTAssertEqual(reopened.ledger.reminderPlan.tripTime, "06:45", "迁移结果已落盘")
    }

    func testClearingContentKeepsTheReminderSwitches() throws {
        try store.updateReminders(CoastReminderPlan(journalEnabled: true, journalTime: "21:30"))
        try store.clearCurrentLedger()
        XCTAssertTrue(store.ledger.trips.isEmpty)
        XCTAssertTrue(store.ledger.reminderPlan.journalEnabled, "清除内容不动提醒开关")
        XCTAssertEqual(store.ledger.reminderPlan.journalTime, "21:30")
    }

    /// 提醒重排挂在这个回调上，所以每个写入点都必须通知到。
    func testChangesNotifyObserversSoRemindersCanBeRescheduled() throws {
        var notifications = 0
        store.onChange = { notifications += 1 }

        try store.saveTrip(CoastTrip(name: "Ridge walk"))
        XCTAssertEqual(notifications, 1, "保存出游")

        try store.addGearItem(tripID: tripID, item: CoastGearItem(title: "Tent"))
        XCTAssertEqual(notifications, 2, "新增装备")

        try store.deleteTrip(id: tripID)
        XCTAssertEqual(notifications, 3, "删除出游")

        try store.updateReminders(CoastReminderPlan(tripEnabled: true))
        XCTAssertEqual(notifications, 4, "修改提醒设置")

        var preferences = store.preferences
        preferences.language = "en"
        try store.updatePreferences(preferences)
        XCTAssertEqual(notifications, 5, "切换语言影响提醒文案")

        try store.activate(accountID: nil)
        XCTAssertEqual(notifications, 6, "登出后需要清掉已排程的提醒")
    }

    // MARK: 足迹

    func testTrailStatsDeriveCountsMonthsAndBadges() throws {
        var trip = try XCTUnwrap(store.ledger.trips.first { $0.id == tripID })
        trip.items = [
            CoastTripItem(activityID: "coastal-afternoon", day: 0, titleSnapshot: "Surf"),
            CoastTripItem(activityID: "shoreline", day: 1, titleSnapshot: "Walk"),
            CoastTripItem(activityID: "pine-camp", day: 2, titleSnapshot: "Camp"),
        ]
        try store.saveTrip(trip)
        for day in ["2026-10-10", "2026-10-11"] {
            var entry = CoastEntry(date: day)
            entry.body = "Words for \(day)"
            entry.isDraft = false
            entry.photos = ["a.jpg"]
            try store.saveEntry(entry)
        }
        var draft = CoastEntry(date: "2026-10-12")
        draft.body = "Draft"
        try store.saveEntry(draft)

        let categoryOf: (String) -> String? = {
            ["coastal-afternoon": "surf", "shoreline": "hike", "pine-camp": "camp"][$0]
        }
        let stats = store.ledger.trailStats(categoryOf: categoryOf)
        XCTAssertEqual(stats.years, [2026])
        XCTAssertEqual(stats.trips, 1)
        XCTAssertEqual(stats.entries, 2, "草稿不计入")
        XCTAssertEqual(stats.photos, 2)
        XCTAssertEqual(stats.categories.map(\.count), [1, 1, 1])
        XCTAssertEqual(stats.months[9], 2, "10 月两篇")
        XCTAssertEqual(stats.months.reduce(0, +), 2)
        XCTAssertFalse(stats.isEmpty)
        XCTAssertFalse(stats.firstLesson.unlocked)
        XCTAssertFalse(stats.threeDayTrip.unlocked, "出游尚未完成")
        XCTAssertEqual(stats.streakLength, 2)
        XCTAssertFalse(stats.streak7.unlocked)

        // 没有 categoryOf 时统计仍可用，分类计数为 0。
        XCTAssertEqual(store.ledger.trailStats().categories.map(\.count), [0, 0, 0])
        // 另一年为空。
        let other = store.ledger.trailStats(year: 2025, categoryOf: categoryOf)
        XCTAssertTrue(other.isEmpty)
        XCTAssertEqual(other.trips, 0)
    }

    func testBadgesUnlockOnTheDocumentedRules() throws {
        // 首课完成 = 任一课程 completed，日期取最早的 completedAt。
        try store.setProgress(lessonID: "board-basics", step: 3, completed: true)
        // 三日出游 = 已完成且起止跨度 >= 3 天（end - start >= 2）。
        var trip = try XCTUnwrap(store.ledger.trips.first { $0.id == tripID })
        trip.completed = true
        try store.saveTrip(trip)
        // 连续 7 天 = 7 个自然日各有至少一篇非草稿手记。
        for day in 10...16 {
            var entry = CoastEntry(date: "2026-10-\(day)")
            entry.body = "Day \(day)"
            entry.isDraft = false
            try store.saveEntry(entry)
        }
        let stats = store.ledger.trailStats()
        XCTAssertTrue(stats.firstLesson.unlocked)
        XCTAssertFalse(stats.firstLesson.at.isEmpty)
        XCTAssertTrue(stats.threeDayTrip.unlocked)
        XCTAssertEqual(stats.threeDayTrip.at, "2026-10-12")
        XCTAssertEqual(stats.streakLength, 7)
        XCTAssertTrue(stats.streak7.unlocked)
        XCTAssertEqual(stats.streak7.at, "2026-10-16")

        // 中间断一天就不连续；剩下两段各 3 天。
        let middle = try XCTUnwrap(store.ledger.entries.first { $0.date == "2026-10-13" })
        try store.deleteEntry(id: middle.id)
        let broken = store.ledger.trailStats()
        XCTAssertFalse(broken.streak7.unlocked)
        XCTAssertEqual(broken.streakLength, 3)

        // 两天的出游拿不到三日徽章。
        var short = CoastTrip(name: "Two days", start: "2026-11-01", end: "2026-11-02")
        short.completed = true
        try store.saveTrip(short)
        try store.deleteTrip(id: tripID)
        XCTAssertFalse(store.ledger.trailStats().threeDayTrip.unlocked)
    }

    func testTripsWithoutDatesStayOutOfAYearFilterButCountInAll() throws {
        try store.saveTrip(CoastTrip(name: "Someday"))
        XCTAssertEqual(store.ledger.trailStats().trips, 2, "全部包含未定日期的出游")
        XCTAssertEqual(store.ledger.trailStats(year: 2026).trips, 1, "按年筛选排除未定日期")
    }

    func testStatsNeverWriteToDisk() throws {
        try store.addGearItem(tripID: tripID, item: CoastGearItem(title: "Tent", category: "camp"))
        let before = try Data(contentsOf: ledgerFile())
        _ = store.ledger.trailStats()
        _ = store.ledger.tagIndex
        let after = try Data(contentsOf: ledgerFile())
        XCTAssertEqual(before, after, "派生统计不落盘")
    }

    private func ledgerFile() throws -> URL {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        return try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("ledger-") })
    }

    // MARK: 强制登录

    func testChecklistAndReminderWritesRequireAnAccount() throws {
        let trip = tripID!
        try store.activate(accountID: nil)
        expectKey("account.required") {
            try self.store.addGearItem(tripID: trip, item: CoastGearItem(title: "Tent"))
        }
        expectKey("account.required") {
            try self.store.toggleGearItem(tripID: trip, itemID: "any")
        }
        expectKey("account.required") { try self.store.clearGear(tripID: trip) }
        expectKey("account.required") {
            _ = try self.store.applyGearTemplate(tripID: trip, items: [])
        }
    }
}
