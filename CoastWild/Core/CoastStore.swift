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
        }
    }

    public func activate(accountID: String?) throws {
        guard let accountID else {
            self.accountID = nil
            ledger = CoastLedger()
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
    }

    public func updatePreferences(_ next: CoastPreferences) throws {
        let data = try encode(next)
        try write(data, to: preferencesURL)
        preferences = next
    }

    public func commit(_ next: CoastLedger) throws {
        guard let accountID else { throw CoastStoreError("account.required") }
        let data = try encode(next)
        try write(data, to: ledgerURL(for: accountID))
        ledger = next
    }

    public func saveTrip(_ trip: CoastTrip) throws {
        try requireAccount()
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

    public func clearCurrentLedger() throws {
        try commit(CoastLedger())
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
