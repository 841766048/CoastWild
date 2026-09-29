import Foundation

public struct CoastStoreError: LocalizedError, Equatable {
    public let key: String
    public let underlyingError: Error?

    public init(_ key: String, underlyingError: Error? = nil) {
        self.key = key
        self.underlyingError = underlyingError
    }

    public var errorDescription: String? { key }

    public static func == (lhs: CoastStoreError, rhs: CoastStoreError) -> Bool {
        lhs.key == rhs.key
    }
}

public final class CoastStore {
    public private(set) var ledger: CoastLedger
    public private(set) var preferences: CoastPreferences
    public private(set) var accountID: String?

    /// 账本、偏好或当前账号发生变化后调用。本地提醒据此整体重排，
    /// 这样调用方不必在每个写入点各加一次。初始化过程中的加载不触发。
    public var onChange: (() -> Void)?

    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL) throws {
        self.directory = directory.standardizedFileURL
        self.fileManager = .default
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.ledger = CoastLedger()
        self.preferences = CoastPreferences()
        do {
            try fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        } catch {
            throw CoastStoreError("storage.directory", underlyingError: error)
        }
        if fileManager.fileExists(atPath: preferencesURL.path) {
            preferences = try read(CoastPreferences.self, from: preferencesURL)
            if preferences.language != "en" {
                try updatePreferences(preferences, notify: false)
            }
        }
    }

    public func activate(accountID: String?) throws {
        guard let accountID else {
            self.accountID = nil
            ledger = CoastLedger()
            onChange?()
            return
        }
        let url = ledgerURL(for: accountID)
        let loaded: CoastLedger
        if fileManager.fileExists(atPath: url.path) {
            loaded = try read(CoastLedger.self, from: url)
        } else {
            loaded = CoastLedger()
        }
        self.accountID = accountID
        ledger = loaded
        try migrateLegacyReminders()
        onChange?()
    }

    /// 提醒计划早期存在全局 preferences 里，会在同设备的多个账号之间串。
    /// 首个登入的账号接手这份旧设置，随后清空全局字段，其余账号从默认值开始。
    private func migrateLegacyReminders() throws {
        guard let legacy = preferences.reminders else { return }
        if ledger.reminders == nil {
            var next = ledger
            next.reminders = legacy
            try commit(next, notify: false)
        }
        var cleared = preferences
        cleared.reminders = nil
        try updatePreferences(cleared, notify: false)
    }

    public func updatePreferences(_ next: CoastPreferences) throws {
        try updatePreferences(next, notify: true)
    }

    private func updatePreferences(_ next: CoastPreferences, notify: Bool) throws {
        var next = next
        next.language = "en"
        let data = try encode(next)
        try write(data, to: preferencesURL)
        preferences = next
        if notify { onChange?() }
    }

    public func commit(_ next: CoastLedger) throws {
        try commit(next, notify: true)
    }

    private func commit(_ next: CoastLedger, notify: Bool) throws {
        guard let accountID else { throw CoastStoreError("account.required") }
        let data = try encode(next)
        try write(data, to: ledgerURL(for: accountID))
        ledger = next
        if notify { onChange?() }
    }

    public func saveTrip(_ incoming: CoastTrip) throws {
        try requireAccount()
        var trip = incoming
        // 出游表单不提交装备清单；gear 为 nil 时保留已有清单，不当作清空。
        // 要清空请用 clearGear(tripID:)。
        if trip.gear == nil {
            trip.gear = ledger.trips.first(where: { $0.id == trip.id })?.gear
        }
        if let error = CoastValidation.trip(trip) { throw CoastStoreError(error) }
        if trip.items.contains(where: { $0.day < 0 }) {
            throw CoastStoreError("trip.activity.dayOutOfRange")
        }
        var activityDays = Set<ActivityDay>()
        for item in trip.items {
            guard activityDays.insert(ActivityDay(activityID: item.activityID, day: item.day)).inserted else {
                throw CoastStoreError("trip.activity.duplicate")
            }
        }
        let priorMaximumDay = ledger.trips.first(where: { $0.id == trip.id })?.items.map(\.day).max()
        let submittedMaximumDay = trip.items.map(\.day).max()
        let maximumDay = [priorMaximumDay, submittedMaximumDay].compactMap { $0 }.max()
        if let maximumDay, maximumDay < 0 || maximumDay > maximumAllowedDay(for: trip) {
            throw CoastStoreError("trip.date.excludesItems")
        }
        var next = ledger
        if let index = next.trips.firstIndex(where: { $0.id == trip.id }) {
            next.trips[index] = trip
        } else {
            next.trips.append(trip)
        }
        try commit(next)
    }

    public func deleteTrip(id: String) throws {
        try requireAccount()
        var next = ledger
        next.trips.removeAll { $0.id == id }
        for index in next.entries.indices where next.entries[index].tripID == id {
            next.entries[index].tripID = nil
        }
        try commit(next)
    }

    public func addActivity(tripID: String, activityID: String, title: String, day: Int) throws {
        try requireAccount()
        guard let tripIndex = ledger.trips.firstIndex(where: { $0.id == tripID }) else {
            throw CoastStoreError("trip.notFound")
        }
        let trip = ledger.trips[tripIndex]
        guard day >= 0, day <= maximumAllowedDay(for: trip) else {
            throw CoastStoreError("trip.activity.dayOutOfRange")
        }
        guard !trip.items.contains(where: { $0.activityID == activityID && $0.day == day }) else {
            throw CoastStoreError("trip.activity.duplicate")
        }
        var next = ledger
        next.trips[tripIndex].items.append(CoastTripItem(activityID: activityID, day: day, titleSnapshot: title))
        try commit(next)
    }

    public func saveEntry(_ entry: CoastEntry) throws {
        try requireAccount()
        if entry.title.count > 80 { throw CoastStoreError("entry.title.tooLong") }
        if entry.body.count > 10_000 { throw CoastStoreError("entry.body.tooLong") }
        if entry.photos.count > 12 { throw CoastStoreError("entry.photos.tooMany") }
        // 标签上限对草稿同样生效，避免草稿里攒下越界数据。
        if let error = CoastValidation.tags(entry.tagList) { throw CoastStoreError(error) }
        if !entry.isDraft, let error = CoastValidation.entry(entry) { throw CoastStoreError(error) }
        if let tripID = entry.tripID, !ledger.trips.contains(where: { $0.id == tripID }) {
            throw CoastStoreError("entry.trip.notFound")
        }
        var saved = entry
        if !saved.isDraft && saved.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saved.title = preferences.language.hasPrefix("zh") ? "未命名手记" : "Untitled entry"
        }
        var next = ledger
        if !saved.isDraft, let sourceEntryID = saved.sourceEntryID {
            guard next.entries.contains(where: { $0.id == sourceEntryID && !$0.isDraft }) else {
                throw CoastStoreError("entry.source.notFound")
            }
            let draftID = saved.id
            saved.id = sourceEntryID
            saved.sourceEntryID = nil
            var replaced: [CoastEntry] = []
            for current in next.entries {
                if current.id == sourceEntryID {
                    replaced.append(saved)
                } else if current.id != draftID {
                    replaced.append(current)
                }
            }
            next.entries = replaced
            try commit(next)
            return
        }
        if let index = next.entries.firstIndex(where: { $0.id == saved.id }) {
            next.entries[index] = saved
        } else {
            next.entries.append(saved)
        }
        try commit(next)
    }

    public func deleteEntry(id: String) throws {
        try requireAccount()
        var next = ledger
        next.entries.removeAll { $0.id == id || $0.sourceEntryID == id }
        try commit(next)
    }

    public func toggleBookmark(_ id: String) throws {
        try requireAccount()
        var next = ledger
        if next.bookmarks.contains(id) {
            next.bookmarks.remove(id)
        } else {
            next.bookmarks.insert(id)
        }
        try commit(next)
    }

    public func setProgress(lessonID: String, step: Int, completed: Bool) throws {
        try requireAccount()
        guard step >= 0 else { throw CoastStoreError("progress.step.invalid") }
        var next = ledger
        let current = next.progress[lessonID] ?? CoastProgress()
        next.progress[lessonID] = CoastProgress(
            step: step,
            completed: current.completed || completed,
            completedAt: current.completedAt ?? (completed ? Date() : nil)
        )
        try commit(next)
    }

    public func updateReminders(_ plan: CoastReminderPlan) throws {
        try requireAccount()
        if let error = CoastValidation.reminders(plan) { throw CoastStoreError(error) }
        var next = ledger
        next.reminderPlan = plan
        try commit(next)
    }

    /// 新增一项装备。标题去首尾空白，排序追加到末尾。
    public func addGearItem(tripID: String, item: CoastGearItem) throws {
        try requireAccount()
        guard let index = ledger.trips.firstIndex(where: { $0.id == tripID }) else {
            throw CoastStoreError("trip.notFound")
        }
        var list = ledger.trips[index].gearList
        if list.count >= CoastGearItem.itemLimit { throw CoastStoreError("checklist.tooMany") }
        var incoming = item
        incoming.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        incoming.sortOrder = (list.map(\.sortOrder).max() ?? -1) + 1
        if let error = CoastValidation.gearItem(incoming) { throw CoastStoreError(error) }
        if list.contains(where: { $0.category == incoming.category && $0.foldedTitle == incoming.foldedTitle }) {
            throw CoastStoreError("checklist.duplicate")
        }
        list.append(incoming)
        var next = ledger
        next.trips[index].gearList = list
        try commit(next)
    }

    /// 改名或换分组。不影响勾选状态。
    public func updateGearItem(
        tripID: String, itemID: String, title: String? = nil, category: String? = nil
    ) throws {
        try requireAccount()
        guard let index = ledger.trips.firstIndex(where: { $0.id == tripID }) else {
            throw CoastStoreError("trip.notFound")
        }
        var list = ledger.trips[index].gearList
        guard let at = list.firstIndex(where: { $0.id == itemID }) else {
            throw CoastStoreError("checklist.notFound")
        }
        var item = list[at]
        if let title { item.title = title.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let category { item.category = category }
        if let error = CoastValidation.gearItem(item) { throw CoastStoreError(error) }
        if list.enumerated().contains(where: { offset, other in
            offset != at && other.category == item.category && other.foldedTitle == item.foldedTitle
        }) {
            throw CoastStoreError("checklist.duplicate")
        }
        list[at] = item
        var next = ledger
        next.trips[index].gearList = list
        try commit(next)
    }

    public func toggleGearItem(tripID: String, itemID: String) throws {
        try requireAccount()
        guard let index = ledger.trips.firstIndex(where: { $0.id == tripID }) else {
            throw CoastStoreError("trip.notFound")
        }
        var list = ledger.trips[index].gearList
        guard let at = list.firstIndex(where: { $0.id == itemID }) else {
            throw CoastStoreError("checklist.notFound")
        }
        list[at].done.toggle()
        var next = ledger
        next.trips[index].gearList = list
        try commit(next)
    }

    public func removeGearItem(tripID: String, itemID: String) throws {
        try requireAccount()
        guard let index = ledger.trips.firstIndex(where: { $0.id == tripID }) else {
            throw CoastStoreError("trip.notFound")
        }
        var list = ledger.trips[index].gearList
        guard list.contains(where: { $0.id == itemID }) else {
            throw CoastStoreError("checklist.notFound")
        }
        list.removeAll { $0.id == itemID }
        var next = ledger
        next.trips[index].gearList = list
        try commit(next)
    }

    /// 套用清单模板：只补充缺少的物品，已在清单里的一律跳过，
    /// 不改动任何勾选状态。返回实际补充的数量。
    /// 去重两把钥匙：模板物品用跨语言稳定的 sourceKey，手工添加的退回标题比对。
    @discardableResult
    public func applyGearTemplate(tripID: String, items: [CoastGearItem]) throws -> Int {
        try requireAccount()
        guard let index = ledger.trips.firstIndex(where: { $0.id == tripID }) else {
            throw CoastStoreError("trip.notFound")
        }
        var list = ledger.trips[index].gearList
        var present = Set<String>()
        for item in list {
            present.insert("t\u{0}\(item.category)\u{0}\(item.foldedTitle)")
            if let key = item.sourceKey { present.insert("s\u{0}\(key)") }
        }
        var order = (list.map(\.sortOrder).max() ?? -1) + 1
        var added: [CoastGearItem] = []
        for raw in items {
            var item = raw
            item.title = raw.title.trimmingCharacters(in: .whitespacesAndNewlines)
            item.done = false
            item.sortOrder = order
            if let error = CoastValidation.gearItem(item) { throw CoastStoreError(error) }
            var keys = ["t\u{0}\(item.category)\u{0}\(item.foldedTitle)"]
            if let key = item.sourceKey { keys.append("s\u{0}\(key)") }
            if keys.contains(where: present.contains) { continue }
            for key in keys { present.insert(key) }
            added.append(item)
            order += 1
        }
        if list.count + added.count > CoastGearItem.itemLimit {
            throw CoastStoreError("checklist.tooMany")
        }
        guard !added.isEmpty else { return 0 }
        list.append(contentsOf: added)
        var next = ledger
        next.trips[index].gearList = list
        try commit(next)
        return added.count
    }

    public func clearGear(tripID: String) throws {
        try requireAccount()
        guard let index = ledger.trips.firstIndex(where: { $0.id == tripID }) else {
            throw CoastStoreError("trip.notFound")
        }
        var next = ledger
        next.trips[index].gearList = []
        try commit(next)
    }

    /// 清空全部勾选，保留物品本身。
    public func clearGearTicks(tripID: String) throws {
        try requireAccount()
        guard let index = ledger.trips.firstIndex(where: { $0.id == tripID }) else {
            throw CoastStoreError("trip.notFound")
        }
        var next = ledger
        next.trips[index].gearList = next.trips[index].gearList.map { item in
            var copy = item
            copy.done = false
            return copy
        }
        try commit(next)
    }

    /// 清除内容，但保留提醒开关本身——确认文案只承诺删除出游、手记、收藏与进度。
    public func clearCurrentLedger() throws {
        try commit(CoastLedger(reminders: ledger.reminders))
    }

    public func deleteCurrentAccountData() throws {
        guard let accountID else { throw CoastStoreError("account.required") }
        let url = ledgerURL(for: accountID)
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        } catch {
            throw CoastStoreError("storage.delete", underlyingError: error)
        }
        self.accountID = nil
        ledger = CoastLedger()
    }

    public func exportData() throws -> Data {
        try requireAccount()
        return try encode(ledger)
    }

    private var preferencesURL: URL {
        directory.appendingPathComponent("preferences.json", isDirectory: false)
    }

    private func ledgerURL(for accountID: String) -> URL {
        directory.appendingPathComponent("ledger-\(stableHash(accountID)).json", isDirectory: false)
    }

    private func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func requireAccount() throws {
        if accountID == nil { throw CoastStoreError("account.required") }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw CoastStoreError("storage.encode", underlyingError: error)
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CoastStoreError("storage.read", underlyingError: error)
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw CoastStoreError("storage.decode", underlyingError: error)
        }
    }

    private func write(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw CoastStoreError("storage.write", underlyingError: error)
        }
    }

    private func maximumAllowedDay(for trip: CoastTrip) -> Int {
        guard let start = CoastValidation.parseDate(trip.start),
              let end = CoastValidation.parseDate(trip.end) else {
            return 0
        }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: end).day ?? 0
    }
}

private struct ActivityDay: Hashable {
    let activityID: String
    let day: Int
}
