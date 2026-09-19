import Foundation

public struct CoastPreferences: Codable, Equatable {
    public var language: String
    public var region: String
    public var distanceUnit: String
    public var temperatureUnit: String
    public var onboardingDone: Bool
    public var interests: [String]?

    public init(
        language: String = "zh-Hans",
        region: String = "CN",
        distanceUnit: String = "km",
        temperatureUnit: String = "c",
        onboardingDone: Bool = false,
        interests: [String]? = nil
    ) {
        self.language = language
        self.region = region
        self.distanceUnit = distanceUnit
        self.temperatureUnit = temperatureUnit
        self.onboardingDone = onboardingDone
        self.interests = interests
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

    public init(
        id: String = UUID().uuidString,
        name: String,
        start: String = "",
        end: String = "",
        notes: String = "",
        timeZone: String = "Asia/Shanghai",
        completed: Bool = false,
        items: [CoastTripItem] = []
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.notes = notes
        self.timeZone = timeZone
        self.completed = completed
        self.items = items
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

public struct CoastEntry: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var body: String
    public var date: String
    public var tripID: String?
    public var activityID: String?
    public var photos: [String]
    public var isDraft: Bool
    public var sourceEntryID: String?

    public init() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        self.init(date: formatter.string(from: Date()))
    }

    /// New entries follow the selected content region; persisted dates are unchanged.
    public init(region: String, now: Date = Date()) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: region == "CN" ? "Asia/Shanghai" : "America/Los_Angeles")
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
        sourceEntryID: String? = nil
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
    public var trips: [CoastTrip]
    public var entries: [CoastEntry]
    public var bookmarks: Set<String>
    public var progress: [String: CoastProgress]

    public init(
        trips: [CoastTrip] = [],
        entries: [CoastEntry] = [],
        bookmarks: Set<String> = [],
        progress: [String: CoastProgress] = [:]
    ) {
        self.trips = trips
        self.entries = entries
        self.bookmarks = bookmarks
        self.progress = progress
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
        return nil
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
