import Foundation
import CryptoKit

/// Public catalog REST transport contract; private note sync continues using the SDK.
public enum PublicContentREST {
    public enum Failure: Error, Equatable { case invalidToken, invalidDocument, http(Int) }
    public static let maximumResponseBytes = 2 * 1024 * 1024

    public static func request(token: String) throws -> URLRequest {
        guard !token.isEmpty, !token.contains(where: { $0.isWhitespace || $0.isNewline })
        else { throw Failure.invalidToken }
        let url = URL(string: "https://firestore.googleapis.com/v1/projects/coast-wild-20260915/databases/(default)/documents/publicCatalog/current")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    public static func fetch(token: (Bool) async throws -> String,
                             send: (URLRequest) async throws -> (Int, Data)) async throws -> PublicContentRelease {
        for attempt in 0...1 {
            try Task.checkCancellation()
            let request = try await request(token: token(attempt == 1))
            let (status, data) = try await send(request)
            if status == 401 && attempt == 0 { continue }
            guard status == 200 else { throw Failure.http(status) }
            return try decode(data)
        }
        throw Failure.http(401)
    }

    public static func decode(_ data: Data) throws -> PublicContentRelease {
        guard data.count <= maximumResponseBytes,
              let document = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = document["fields"] as? [String: Any]
        else { throw Failure.invalidDocument }
        func string(_ fields: [String: Any], _ key: String, type: String = "stringValue") throws -> String {
            guard let value = fields[key] as? [String: Any], value.count == 1,
                  let result = value[type] as? String else { throw Failure.invalidDocument }
            return result
        }
        func integer(_ fields: [String: Any], _ key: String) throws -> Int {
            guard let result = Int(try string(fields, key, type: "integerValue")) else { throw Failure.invalidDocument }
            return result
        }
        guard let imagesField = fields["images"] as? [String: Any],
              let array = imagesField["arrayValue"] as? [String: Any],
              array["values"] == nil || array["values"] is [[String: Any]]
        else { throw Failure.invalidDocument }
        let values = array["values"] as? [[String: Any]] ?? []
        guard values.count <= 128 else { throw Failure.invalidDocument }
        let images = try values.map { value -> PublicContentImage in
            guard let map = value["mapValue"] as? [String: Any],
                  let item = map["fields"] as? [String: Any] else { throw Failure.invalidDocument }
            return try PublicContentImage(name: string(item, "name"), path: string(item, "path"),
                                          sha256: string(item, "sha256"), bytes: integer(item, "bytes"))
        }
        let release = try PublicContentRelease(schemaVersion: integer(fields, "schemaVersion"),
            version: string(fields, "version"), catalogJSON: string(fields, "catalogJSON"), images: images)
        try release.validate()
        return release
    }
}

public struct PublicContentImage: Codable, Equatable {
    public var name: String
    public var path: String
    public var sha256: String
    public var bytes: Int
}

public enum PublicContentError: Error { case invalidRelease, invalidImage }

public struct PublicContentRelease: Codable, Equatable {
    public var schemaVersion: Int
    public var version: String
    public var catalogJSON: String
    public var images: [PublicContentImage]

    public static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    public func validate() throws {
        guard schemaVersion == 1, Self.matches(version, "^[a-f0-9]{64}$"),
              catalogJSON.utf8.count < 700_000, images.count <= 128,
              Set(images.map(\.name)).count == images.count else { throw PublicContentError.invalidRelease }
        var total = 0
        for image in images {
            guard Self.matches(image.name, "^[A-Za-z0-9_-]{1,100}$"),
                  Self.matches(image.sha256, "^[a-f0-9]{64}$"),
                  image.bytes > 0, image.bytes <= 8 * 1024 * 1024,
                  ["jpg", "jpeg", "png", "webp"].contains(URL(fileURLWithPath: image.path).pathExtension),
                  image.path == "content/\(version)/images/\(image.name).\(URL(fileURLWithPath: image.path).pathExtension)"
            else { throw PublicContentError.invalidImage }
            total += image.bytes
        }
        guard total <= 60 * 1024 * 1024,
              try Self.referencedImages(in: Data(catalogJSON.utf8)) == Set(images.map(\.name))
        else { throw PublicContentError.invalidRelease }
    }

    public static func referencedImages(in data: Data) throws -> Set<String> {
        guard data.count < 700_000,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys).isSubset(of: ["items", "lessons", "home", "learn", "categories", "gearTemplates"]),
              let items = root["items"] as? [[String: Any]],
              let lessons = root["lessons"] as? [[String: Any]],
              let categories = root["categories"] as? [[String: Any]]
        else { throw PublicContentError.invalidRelease }
        func keys(_ rows: [[String: Any]]) throws -> Set<String> {
            let values = rows.compactMap { $0["key"] as? String }
            guard values.count == rows.count, Set(values).count == values.count,
                  values.allSatisfy({ matches($0, "^[A-Za-z0-9_-]{1,100}$") }) else { throw PublicContentError.invalidRelease }
            return Set(values)
        }
        let itemIDs = try keys(items), lessonIDs = try keys(lessons), categoryIDs = try keys(categories)
        guard (items + lessons).allSatisfy({ categoryIDs.contains($0["category"] as? String ?? "") })
        else { throw PublicContentError.invalidRelease }
        let decoded = try JSONDecoder().decode([CoastLesson].self, from: JSONSerialization.data(withJSONObject: lessons))
        guard decoded.allSatisfy({ $0.isValid() }), decoded.allSatisfy({ lesson in
            lesson.webDetail?.nextLessonID.map { lessonIDs.contains($0) } ?? true
        }) else { throw PublicContentError.invalidRelease }
        if let home = root["home"] as? [String: Any] {
            guard let hero = home["hero"] as? [String: Any], let tiles = home["tiles"] as? [[String: Any]],
                  ([hero] + tiles).allSatisfy({ itemIDs.contains($0["item"] as? String ?? "") })
            else { throw PublicContentError.invalidRelease }
        }
        var names = Set<String>()
        func visit(_ value: Any) throws {
            if let object = value as? [String: Any] {
                for (key, child) in object {
                    if ["photo", "heroImage", "image"].contains(key) {
                        guard let path = child as? String,
                              matches(path, "^(public/assets/)?[A-Za-z0-9_-]{1,100}(\\.(jpg|jpeg|png|webp))?$")
                        else { throw PublicContentError.invalidImage }
                        names.insert(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                    } else { try visit(child) }
                }
            } else if let list = value as? [Any] { for child in list { try visit(child) } }
        }
        try visit(root)
        return names
    }
}

/// Immutable generations plus an atomic pointer: interrupted downloads never replace working content.
public struct PublicContentCache {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    private var pointer: URL { directory.appendingPathComponent("current.json") }
    private struct Active: Codable { let folder: String; let release: PublicContentRelease }

    private func active() throws -> Active {
        let data = try Data(contentsOf: pointer)
        guard data.count < 900_000 else { throw PublicContentError.invalidRelease }
        let value = try JSONDecoder().decode(Active.self, from: data)
        guard UUID(uuidString: value.folder) != nil else { throw PublicContentError.invalidRelease }
        try value.release.validate()
        return value
    }

    public func load() -> PublicContentRelease? {
        do {
            let value = try active()
            for image in value.release.images {
                let url = directory.appendingPathComponent(value.folder).appendingPathComponent(image.name)
                guard try url.resourceValues(forKeys: [.fileSizeKey]).fileSize == image.bytes else { return nil }
                let data = try Data(contentsOf: url)
                guard PublicContentRelease.digest(data) == image.sha256 else { return nil }
            }
            return value.release
        } catch { return nil }
    }

    public func imageURL(named name: String, release: PublicContentRelease) -> URL? {
        imageURLs(release: release)[name]
    }

    public func imageURLs(release: PublicContentRelease) -> [String: URL] {
        guard let value = try? active(), value.release.version == release.version else { return [:] }
        return Dictionary(uniqueKeysWithValues: release.images.map {
            ($0.name, directory.appendingPathComponent(value.folder).appendingPathComponent($0.name))
        })
    }

    public func install(_ release: PublicContentRelease, images: [String: Data]) throws {
        try release.validate()
        for image in release.images {
            guard let data = images[image.name], data.count == image.bytes,
                  PublicContentRelease.digest(data) == image.sha256 else { throw PublicContentError.invalidImage }
        }
        let folder = UUID().uuidString
        let target = directory.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        do {
            for image in release.images { try images[image.name]!.write(to: target.appendingPathComponent(image.name), options: .atomic) }
            let old = try? active()
            try JSONEncoder().encode(Active(folder: folder, release: release)).write(to: pointer, options: .atomic)
            if let old, old.folder != folder {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(old.folder))
            }
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }
}

/// Serializes expensive public-content preparation away from the main actor.
public actor PublicContentWorker {
    private let cache: PublicContentCache

    public init(cache: PublicContentCache) { self.cache = cache }

    public func fetchAndInstall(
        _ release: PublicContentRelease,
        fetch: @Sendable (PublicContentImage) async throws -> Data,
        validateImage: @Sendable (Data) -> Bool
    ) async throws -> [String: URL] {
        try release.validate()
        var images: [String: Data] = [:]
        for image in release.images {
            try Task.checkCancellation()
            let data = try await fetch(image)
            guard data.count == image.bytes,
                  PublicContentRelease.digest(data) == image.sha256,
                  validateImage(data)
            else { throw PublicContentError.invalidImage }
            images[image.name] = data
        }
        try Task.checkCancellation()
        try cache.install(release, images: images)
        return cache.imageURLs(release: release)
    }
}
