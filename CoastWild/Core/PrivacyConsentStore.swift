import Foundation

struct PrivacyConsentStore {
    let defaults: UserDefaults
    let key: String
    let currentVersion: Int

    var isAccepted: Bool {
        defaults.integer(forKey: key) == currentVersion
    }

    func accept() {
        defaults.set(currentVersion, forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}

