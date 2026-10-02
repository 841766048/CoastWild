import Foundation
import ImageIO

/// ImageIO runs on a utility task; thumbnails are redrawn/re-encoded without source EXIF/GPS.
enum NotePhotoCodec {
  /// Called synchronously on the store's actor immediately before merging note references.
  static func installRestoredFiles(_ filenames: [String], from staging: URL, to live: URL) throws {
    let files = Array(Set(filenames))
    for name in files {
      _ = try NotePhotoPayload.id(filename: name)
      guard FileManager.default.fileExists(atPath: live.appendingPathComponent(name).path)
        || FileManager.default.fileExists(atPath: staging.appendingPathComponent(name).path)
      else { throw CoastStoreError("notes.missingPhoto") }
    }
    try FileManager.default.createDirectory(at: live, withIntermediateDirectories: true)
    for name in files where !FileManager.default.fileExists(atPath: live.appendingPathComponent(name).path) {
      try FileManager.default.moveItem(at: staging.appendingPathComponent(name), to: live.appendingPathComponent(name))
    }
  }

  static func compress(_ url: URL) throws -> NotePhotoPayload {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
    else { throw CoastStoreError("notes.invalidPhoto") }
    for maximum in [1600, 1200, 900, 640, 400, 240] {
      try Task.checkCancellation()
      guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maximum,
      ] as CFDictionary) else { throw CoastStoreError("notes.invalidPhoto") }
      for quality in [0.8, 0.6, 0.4] {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil)
        else { throw CoastStoreError("notes.invalidPhoto") }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        if CGImageDestinationFinalize(destination), output.length <= NotePhotoPayload.maximumBytes {
          return try NotePhotoPayload(jpeg: output as Data, width: image.width, height: image.height)
        }
      }
    }
    throw CoastStoreError("notes.invalidPhoto")
  }

  static func restore(_ payload: NotePhotoPayload, to url: URL) throws {
    let data = try payload.decodedJPEG()
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          properties[kCGImagePropertyPixelWidth] as? Int == payload.width,
          properties[kCGImagePropertyPixelHeight] as? Int == payload.height,
          CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
    else { throw CoastStoreError("notes.invalidPhoto") }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    #if os(iOS)
    try data.write(to: url, options: [.atomic, .completeFileProtection])
    #else
    // iOS data-protection attributes cannot be written by the macOS test host.
    try data.write(to: url, options: .atomic)
    #endif
  }
}

public enum CoastLessonDetailType: String, Codable, Equatable {
    case web
    case native
}

public struct CoastSourceLink: Codable, Equatable {
    public let title: [String: String]
    public let organization: String
    public let url: String
}

public struct CoastWebBlock: Codable, Equatable {
    public let type: String
    public let title: [String: String]?
    public let body: [String: String]?
    public let image: String?
    public let icon: String?
    public let items: [[String: String]]?
}

public struct CoastWebDetail: Codable, Equatable {
    public let author: [String: String]
    public let updatedAt: String
    public let highlights: [[String: String]]
    public let blocks: [CoastWebBlock]
    public let nextLessonID: String?
}

public struct CoastStep: Codable, Equatable {
    public let title: [String: String]
    public let body: [String: String]
    public let image: String
    public let icon: String?
    public let callout: [String: String]?

    public init(
        title: [String: String], body: [String: String], image: String,
        icon: String? = nil, callout: [String: String]? = nil
    ) {
        self.title = title
        self.body = body
        self.image = image
        self.icon = icon
        self.callout = callout
    }

    public var assetName: String {
        URL(fileURLWithPath: image).deletingPathExtension().lastPathComponent
    }
}

public struct CoastNativeDetail: Codable, Equatable {
    public let steps: [CoastStep]
}

public struct CoastLesson: Codable, Equatable {
    public let key: String
    public let category: String
    public let detailType: CoastLessonDetailType
    public let title: [String: String]
    public let summary: [String: String]
    public let group: [String: String]
    public let heroImage: String
    public let icon: String
    public let readingMinutes: Int
    public let level: String
    public let tags: [[String: String]]
    public let sourceLinks: [CoastSourceLink]
    public let webDetail: CoastWebDetail?
    public let nativeDetail: CoastNativeDetail?

    public var image: String {
        URL(fileURLWithPath: heroImage).deletingPathExtension().lastPathComponent
    }
    public var steps: [CoastStep] { nativeDetail?.steps ?? [] }

    public func isValid() -> Bool {
        let localized = [title, summary, group]
        guard localized.allSatisfy({ $0["en"]?.isEmpty == false && $0["zh-Hans"]?.isEmpty == false }),
              !key.isEmpty, ["surf", "hike", "camp"].contains(category),
              !heroImage.isEmpty, !icon.isEmpty, readingMinutes > 0,
              sourceLinks.allSatisfy({ URL(string: $0.url)?.scheme == "https" })
        else { return false }
        switch detailType {
        case .web: return webDetail != nil && nativeDetail == nil && webDetail?.blocks.isEmpty == false
        case .native: return nativeDetail?.steps.isEmpty == false && webDetail == nil
        }
    }
}

/// Shared motion values keep UIKit transitions consistent with the approved HF-v1 timing.
public enum CoastMotion {
    public static let pushDuration = 0.28
    public static let popDuration = 0.24
    public static let tabDuration = 0.18
    public static let tabOffset = 6.0
    public static let dialogOpenDuration = 0.22
    public static let dialogCloseDuration = 0.16
    public static let dialogOpenScale = 0.96
    public static let dialogCloseScale = 0.98
    public static let reducedDuration = 0.12
}

/// 出发与手记提醒。本机通知，不经过服务器。
public struct CoastReminderPlan: Codable, Equatable {
    public var tripEnabled: Bool
    /// 出发前提前天数，0 表示当天。
    public var tripLeadDays: Int
    public var tripTime: String
    public var includeGearSummary: Bool
    public var journalEnabled: Bool
    public var journalTime: String

    public init(
        tripEnabled: Bool = false,
        tripLeadDays: Int = 1,
        tripTime: String = "08:00",
        includeGearSummary: Bool = true,
        journalEnabled: Bool = false,
        journalTime: String = "20:30"
    ) {
        self.tripEnabled = tripEnabled
        self.tripLeadDays = tripLeadDays
        self.tripTime = tripTime
        self.includeGearSummary = includeGearSummary
        self.journalEnabled = journalEnabled
        self.journalTime = journalTime
    }
}

public struct CoastPreferences: Codable, Equatable {
    public var language: String
    public var distanceUnit: String
    public var temperatureUnit: String
    public var onboardingDone: Bool
    public var interests: [String]?
    /// 历史字段。提醒计划已按账号存进账本，这里只为解码旧 preferences.json 而保留，
    /// 迁移到账本后由 CoastStore 清空。新代码请读写 CoastLedger.reminderPlan。
    public var reminders: CoastReminderPlan?

    public init(
        language: String = "en",
        distanceUnit: String = "km",
        temperatureUnit: String = "c",
        onboardingDone: Bool = false,
        interests: [String]? = nil,
        reminders: CoastReminderPlan? = nil
    ) {
        self.language = language
        self.distanceUnit = distanceUnit
        self.temperatureUnit = temperatureUnit
        self.onboardingDone = onboardingDone
        self.interests = interests
        self.reminders = reminders
    }
}

/// 装备清单里的一项。按出游隔离保存。
public struct CoastGearItem: Codable, Identifiable, Equatable {
    public static let categories = ["surf", "hike", "camp", "general"]
    public static let titleLimit = 40
    public static let itemLimit = 60

    public var id: String
    /// 来自清单模板的物品带这个跨语言稳定标识；自己添加的为 nil。
    /// 套用模板时据此去重，切换语言后仍然不会重复补充同一件东西。
    public var sourceKey: String?
    public var title: String
    public var category: String
    public var done: Bool
    public var sortOrder: Int

    public init(
        id: String = UUID().uuidString,
        sourceKey: String? = nil,
        title: String,
        category: String = "general",
        done: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.sourceKey = sourceKey
        self.title = title
        self.category = category
        self.done = done
        self.sortOrder = sortOrder
    }

    /// 去重与比较用的折叠标题：去首尾空白、压缩空格、忽略大小写。
    public var foldedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .lowercased()
    }
}

public struct CoastTrip: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var start: String
    public var end: String
    public var notes: String
    public var timeZone: String
    public var completed: Bool
    public var items: [CoastTripItem]
    public var coverPhoto: String?
    /// 新增字段保持可选，已有 ledger-*.json 没有这一项也能解码。
    public var gear: [CoastGearItem]?

    public init(
        id: String = UUID().uuidString,
        name: String,
        start: String = "",
        end: String = "",
        notes: String = "",
        timeZone: String = TimeZone.current.identifier,
        completed: Bool = false,
        items: [CoastTripItem] = [],
        coverPhoto: String? = nil,
        gear: [CoastGearItem]? = nil
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.notes = notes
        self.timeZone = timeZone
        self.completed = completed
        self.items = items
        self.coverPhoto = coverPhoto
        self.gear = gear
    }

    public var gearList: [CoastGearItem] {
        get { gear ?? [] }
        set { gear = newValue }
    }

    /// TR05 头部的“已备 n / m 项”与提醒摘要都用这个。
    public var gearProgress: (done: Int, total: Int, left: Int, ratio: Double) {
        let list = gearList
        let done = list.filter(\.done).count
        return (done, list.count, list.count - done, list.isEmpty ? 0 : Double(done) / Double(list.count))
    }

    /// 按固定分组顺序归拢清单，空分组不返回。
    public var gearByCategory: [(category: String, items: [CoastGearItem])] {
        let sorted = gearList.sorted { $0.sortOrder < $1.sortOrder }
        return CoastGearItem.categories.compactMap { category in
            let items = sorted.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }
}

public struct CoastTripItem: Codable, Identifiable, Equatable {
    public var id: String
    public var activityID: String
    public var day: Int
    public var titleSnapshot: String
    public var time: String?

    public init(
        id: String = UUID().uuidString,
        activityID: String,
        day: Int = 0,
        titleSnapshot: String,
        time: String? = nil
    ) {
        self.id = id
        self.activityID = activityID
        self.day = day
        self.titleSnapshot = titleSnapshot
        self.time = time
    }
}

public struct NotePhotoPayload: Codable, Equatable, Sendable {
    public static let maximumBytes = 204_800
    public var base64: String
    public var bytes: Int
    public var sha256: String
    public var width: Int
    public var height: Int
    public var mimeType: String
    public var schemaVersion: Int

    public static func validateIDs(_ ids: [String]) throws {
        guard ids.count <= 12, Set(ids).count == ids.count,
              ids.allSatisfy({ $0.range(of: "^[A-Za-z0-9_-]{1,100}$", options: .regularExpression) != nil })
        else { throw CoastStoreError("notes.invalidPhoto") }
    }

    public static func id(filename: String) throws -> String {
        guard filename.hasSuffix(".jpg") else { throw CoastStoreError("notes.invalidPhoto") }
        let id = String(filename.dropLast(4))
        try validateIDs([id])
        return id
    }

    public init(jpeg: Data, width: Int, height: Int) throws {
        base64 = jpeg.base64EncodedString(); bytes = jpeg.count
        sha256 = PublicContentRelease.digest(jpeg)
        self.width = width; self.height = height
        mimeType = "image/jpeg"; schemaVersion = 1
        _ = try decodedJPEG()
    }

    public func decodedJPEG() throws -> Data {
        guard schemaVersion == 1, mimeType == "image/jpeg",
              (1...1600).contains(width), (1...1600).contains(height),
              bytes > 0, bytes <= Self.maximumBytes, base64.utf8.count <= 273_068,
              let data = Data(base64Encoded: base64), data.count == bytes,
              data.prefix(2) == Data([0xff, 0xd8]), data.suffix(2) == Data([0xff, 0xd9]),
              PublicContentRelease.digest(data) == sha256
        else { throw CoastStoreError("notes.invalidPhoto") }
        return data
    }
}

public struct CoastEntry: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var body: String
    public var date: String
    public var tripID: String?
    public var activityID: String?
    public var photos: [String]
    /// nil is a legacy text-only cloud snapshot; [] is an authoritative empty image list.
    public var cloudPhotoIDs: [String]?
    public var isDraft: Bool
    public var sourceEntryID: String?
    /// 新增字段保持可选，已有账本没有这一项也能解码。
    public var tags: [String]?

    public static let tagLimit = 5
    public static let tagLengthLimit = 12

    public var tagList: [String] {
        get { tags ?? [] }
        set { tags = newValue }
    }

    /// New entries use the device time zone; persisted date strings are unchanged.
    public init(now: Date = Date(), timeZone: TimeZone = .current) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.init(date: formatter.string(from: now))
    }

    public init(
        id: String = UUID().uuidString,
        title: String = "",
        body: String = "",
        date: String,
        tripID: String? = nil,
        activityID: String? = nil,
        photos: [String] = [],
        isDraft: Bool = true,
        sourceEntryID: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.date = date
        self.tripID = tripID
        self.activityID = activityID
        self.photos = photos
        self.isDraft = isDraft
        self.sourceEntryID = sourceEntryID
        self.tags = tags
    }
}

public struct CoastProgress: Codable, Equatable {
    public var step: Int
    public var completed: Bool
    public var completedAt: Date?

    public init(step: Int = 0, completed: Bool = false, completedAt: Date? = nil) {
        self.step = step
        self.completed = completed
        self.completedAt = completedAt
    }
}

public struct CoastLedger: Codable, Equatable {
    /// Durable outbox. Missing on legacy ledgers; deleted IDs remain until acknowledged.
    public var pendingNoteIDs: Set<String>?
    public var noteSyncScope: String?
    public var noteImageSyncVersion: Int?
    public var trips: [CoastTrip]
    public var entries: [CoastEntry]
    public var bookmarks: Set<String>
    public var progress: [String: CoastProgress]
    /// 新增字段保持可选，已有 ledger-*.json 没有这一项也能解码。
    /// 提醒排的是本账号的出游，所以跟账本一起按账号隔离。
    public var reminders: CoastReminderPlan?

    public init(
        trips: [CoastTrip] = [],
        entries: [CoastEntry] = [],
        bookmarks: Set<String> = [],
        progress: [String: CoastProgress] = [:],
        reminders: CoastReminderPlan? = nil
    ) {
        self.trips = trips
        self.entries = entries
        self.bookmarks = bookmarks
        self.progress = progress
        self.reminders = reminders
    }

    /// 未设置过提醒时给默认值，调用方不必处理 nil。
    public var reminderPlan: CoastReminderPlan {
        get { reminders ?? CoastReminderPlan() }
        set { reminders = newValue }
    }

    public var referencedPhotoFilenames: Set<String> {
        Set(entries.flatMap(\.photos) + trips.compactMap(\.coverPhoto))
    }
}

public enum CoastValidation {
    public static func trip(_ value: CoastTrip) -> String? {
        let name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "trip.name.required" }
        if name.count > 60 { return "trip.name.tooLong" }
        if value.notes.count > 1_000 { return "trip.notes.tooLong" }
        if value.items.contains(where: { item in
            guard let time = item.time else { return false }
            return time.range(of: #"^(?:[01]\d|2[0-3]):[0-5]\d$"#, options: .regularExpression) == nil
        }) {
            return "trip.activity.time.invalid"
        }
        if value.start.isEmpty != value.end.isEmpty { return "trip.date.incomplete" }
        if !value.start.isEmpty {
            guard let start = parseDate(value.start), let end = parseDate(value.end) else {
                return "trip.date.invalid"
            }
            if end < start { return "trip.date.range" }
        }
        if let error = gear(value.gearList) { return error }
        return nil
    }

    public static func entry(_ value: CoastEntry) -> String? {
        if value.title.count > 80 { return "entry.title.tooLong" }
        if value.body.count > 10_000 { return "entry.body.tooLong" }
        if value.photos.count > 12 { return "entry.photos.tooMany" }
        if value.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.photos.isEmpty {
            return "entry.content.required"
        }
        if parseDate(value.date) == nil { return "entry.date.invalid" }
        if let error = tags(value.tagList) { return error }
        return nil
    }

    /// 单个装备项。返回 nil 表示通过。
    public static func gearItem(_ value: CoastGearItem) -> String? {
        if value.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "checklist.id.required"
        }
        let title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "checklist.title.required" }
        if title.count > CoastGearItem.titleLimit { return "checklist.title.tooLong" }
        if !CoastGearItem.categories.contains(value.category) { return "checklist.category.invalid" }
        if value.sortOrder < 0 { return "checklist.order.invalid" }
        return nil
    }

    /// 整份清单：逐项校验、数量上限、同分组内标题去重。
    public static func gear(_ value: [CoastGearItem]) -> String? {
        if value.count > CoastGearItem.itemLimit { return "checklist.tooMany" }
        var ids = Set<String>()
        var pairs = Set<String>()
        for item in value {
            if let error = gearItem(item) { return error }
            guard ids.insert(item.id).inserted else { return "checklist.id.duplicate" }
            guard pairs.insert("\(item.category)\u{0}\(item.foldedTitle)").inserted else {
                return "checklist.duplicate"
            }
        }
        return nil
    }

    /// 手记标签：最多 5 个，单个 1–12 字符，同篇不重复（忽略大小写）。
    public static func tags(_ value: [String]) -> String? {
        if value.count > CoastEntry.tagLimit { return "entry.tags.tooMany" }
        var seen = Set<String>()
        for tag in value {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "entry.tag.required" }
            if trimmed.count > CoastEntry.tagLengthLimit { return "entry.tag.tooLong" }
            guard seen.insert(trimmed.lowercased()).inserted else { return "entry.tag.duplicate" }
        }
        return nil
    }

    public static func reminders(_ value: CoastReminderPlan) -> String? {
        if !(0...7).contains(value.tripLeadDays) { return "reminder.lead.invalid" }
        if !isClock(value.tripTime) || !isClock(value.journalTime) { return "reminder.time.invalid" }
        return nil
    }

    static func isClock(_ value: String) -> Bool {
        value.range(of: #"^(?:[01]\d|2[0-3]):[0-5]\d$"#, options: .regularExpression) != nil
    }

    public static func email(_ value: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return value.count <= 254 && value.range(of: pattern, options: .regularExpression) != nil
    }

    public static func password(_ value: String) -> Bool {
        (10...128).contains(value.count)
    }

    static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }
}

/// 足迹统计。纯派生，不落盘。
public struct CoastTrailStats: Equatable {
    public struct Badge: Equatable {
        public var unlocked: Bool
        /// 达成日期，未知或未达成为空。
        public var at: String

        public init(unlocked: Bool = false, at: String = "") {
            self.unlocked = unlocked
            self.at = at
        }
    }

    public var years: [Int] = []
    public var year: Int?
    public var trips: Int = 0
    public var finishedTrips: Int = 0
    public var entries: Int = 0
    public var photos: Int = 0
    /// 按次数倒序的体验分布，key 为 surf / hike / camp。
    public var categories: [(key: String, count: Int)] = []
    /// 1 至 12 月的手记篇数。
    public var months: [Int] = Array(repeating: 0, count: 12)
    public var firstLesson = Badge()
    public var threeDayTrip = Badge()
    public var streak7 = Badge()
    public var streakLength: Int = 0
    public var isEmpty: Bool = true

    public static func == (lhs: CoastTrailStats, rhs: CoastTrailStats) -> Bool {
        lhs.years == rhs.years && lhs.year == rhs.year && lhs.trips == rhs.trips
            && lhs.finishedTrips == rhs.finishedTrips && lhs.entries == rhs.entries
            && lhs.photos == rhs.photos && lhs.months == rhs.months
            && lhs.categories.map(\.key) == rhs.categories.map(\.key)
            && lhs.categories.map(\.count) == rhs.categories.map(\.count)
            && lhs.firstLesson == rhs.firstLesson && lhs.threeDayTrip == rhs.threeDayTrip
            && lhs.streak7 == rhs.streak7 && lhs.streakLength == rhs.streakLength
            && lhs.isEmpty == rhs.isEmpty
    }
}

extension CoastLedger {
    /// 按年筛选后的足迹统计。
    /// categoryOf 把体验 ID 映射到 surf / hike / camp，由调用方从内容库提供，
    /// 这样 Core 不依赖 catalog 资源。
    public func trailStats(
        year: Int? = nil,
        categoryOf: (String) -> String? = { _ in nil }
    ) -> CoastTrailStats {
        func yearOf(_ value: String) -> Int? {
            guard CoastValidation.parseDate(value) != nil, value.count >= 4 else { return nil }
            return Int(value.prefix(4))
        }
        func inScope(_ value: String) -> Bool {
            guard let year else { return true }
            return yearOf(value) == year
        }

        var stats = CoastTrailStats()
        stats.year = year

        let published = entries.filter { !$0.isDraft }
        stats.years = Set(
            published.compactMap { yearOf($0.date) } + trips.compactMap { yearOf($0.start) }
        ).sorted(by: >)

        let scopedTrips = trips.filter { inScope($0.start) }
        let scopedEntries = published.filter { inScope($0.date) }
        stats.trips = scopedTrips.count
        stats.finishedTrips = scopedTrips.filter(\.completed).count
        stats.entries = scopedEntries.count
        stats.photos = scopedEntries.reduce(0) { $0 + $1.photos.count }

        var counts = ["surf": 0, "hike": 0, "camp": 0]
        for trip in scopedTrips {
            for item in trip.items {
                if let category = categoryOf(item.activityID), counts[category] != nil {
                    counts[category, default: 0] += 1
                }
            }
        }
        stats.categories = ["surf", "hike", "camp"]
            .map { (key: $0, count: counts[$0] ?? 0) }
            .sorted { $0.count > $1.count }

        for entry in scopedEntries where entry.date.count >= 7 {
            if let month = Int(entry.date.dropFirst(5).prefix(2)), (1...12).contains(month) {
                stats.months[month - 1] += 1
            }
        }

        let completions = progress.values.filter(\.completed)
        let firstAt = completions.compactMap(\.completedAt).min()
        stats.firstLesson = CoastTrailStats.Badge(
            unlocked: !completions.isEmpty,
            at: firstAt.map(CoastLedger.isoDay) ?? ""
        )

        let calendar = Calendar(identifier: .gregorian)
        let threeDay = scopedTrips
            .filter { $0.completed }
            .filter { trip in
                guard let start = CoastValidation.parseDate(trip.start),
                      let end = CoastValidation.parseDate(trip.end),
                      let span = calendar.dateComponents([.day], from: start, to: end).day
                else { return false }
                return span >= 2
            }
            .sorted { $0.end < $1.end }
            .first
        stats.threeDayTrip = CoastTrailStats.Badge(
            unlocked: threeDay != nil,
            at: threeDay?.end ?? ""
        )

        let streak = CoastLedger.longestStreak(scopedEntries.map(\.date))
        stats.streakLength = streak.length
        stats.streak7 = CoastTrailStats.Badge(
            unlocked: streak.length >= 7,
            at: streak.length >= 7 ? streak.at : ""
        )
        stats.isEmpty = scopedTrips.isEmpty && scopedEntries.isEmpty
        return stats
    }

    /// 最长连续自然日长度与达成那天。
    static func longestStreak(_ dates: [String]) -> (length: Int, at: String) {
        let calendar = Calendar(identifier: .gregorian)
        let sorted = Set(dates).sorted()
        var best = 0
        var bestEnd = ""
        var run = 0
        var previous: Date?
        for day in sorted {
            guard let date = CoastValidation.parseDate(day) else { continue }
            if let previous, calendar.dateComponents([.day], from: previous, to: date).day == 1 {
                run += 1
            } else {
                run = 1
            }
            if run > best {
                best = run
                bestEnd = day
            }
            previous = date
        }
        return (best, bestEnd)
    }

    static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 全部已用标签，按使用次数倒序；草稿不计入。
    public var tagIndex: [(tag: String, count: Int)] {
        var counts: [String: (tag: String, count: Int)] = [:]
        for entry in entries where !entry.isDraft {
            for tag in entry.tagList {
                let folded = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if folded.isEmpty { continue }
                if let current = counts[folded] {
                    counts[folded] = (current.tag, current.count + 1)
                } else {
                    counts[folded] = (tag, 1)
                }
            }
        }
        return counts.values
            .sorted { $0.count > $1.count || ($0.count == $1.count && $0.tag < $1.tag) }
            .map { ($0.tag, $0.count) }
    }
}
