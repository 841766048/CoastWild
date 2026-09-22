import Foundation

protocol AccountDataStore {
    func load() throws -> Data?
    func save(_ data: Data) throws
    func remove() throws
}

struct UserDefaultsAccountDataStore: AccountDataStore {
    let defaults: UserDefaults
    let key: String

    func load() throws -> Data? {
        defaults.data(forKey: key)
    }

    func save(_ data: Data) throws {
        defaults.set(data, forKey: key)
    }

    func remove() throws {
        defaults.removeObject(forKey: key)
    }
}

struct MigratingAccountDataStore: AccountDataStore {
    let destination: any AccountDataStore
    let legacy: any AccountDataStore

    func load() throws -> Data? {
        if let data = try destination.load() {
            return data
        }
        guard let legacyData = try legacy.load() else {
            return nil
        }
        try destination.save(legacyData)
        try legacy.remove()
        return legacyData
    }

    func save(_ data: Data) throws {
        try destination.save(data)
    }

    func remove() throws {
        try destination.remove()
    }
}
