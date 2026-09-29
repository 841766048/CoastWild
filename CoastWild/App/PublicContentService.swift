import UIKit
import FirebaseAuth

/// Never forward authenticated catalog requests to another URL.
private final class PublicContentRedirectGuard: NSObject, URLSessionTaskDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(nil)
  }
}

/// Only administrator-published course assets enter this cache. Journal photos use env.photo().
enum PublicContentImages {
  static var files: [String: URL] = [:] {
    didSet { decoded.removeAllObjects() }
  }
  private static let decoded = NSCache<NSString, UIImage>()
  static func image(named name: String) -> UIImage? {
    if let cached = decoded.object(forKey: name as NSString) { return cached }
    if let url = files[name], let image = UIImage(contentsOfFile: url.path) {
      decoded.totalCostLimit = 32 * 1024 * 1024
      decoded.setObject(image, forKey: name as NSString, cost: Int(image.size.width * image.size.height * 4))
      return image
    }
    return UIImage(named: name)
  }
}

final class PublicContentService {
  static let changed = Notification.Name("CoastWild.publicContentChanged")
  private let cache: PublicContentCache
  private let worker: PublicContentWorker
  private let loader: PublicContentLoader<PublicContentRelease>
  var current: PublicContentRelease? { loader.current }
  var state: PublicContentLoadState { loader.state }
  private var task: Task<Void, Never>?
  #if DEBUG
  private var fixtureAttempts = 0
  @MainActor func refreshEmptyFixture(force: Bool, apply: @escaping @MainActor (Catalog) -> Void) {
    guard task == nil else { return }
    task = Task { [weak self] in
      guard let self else { return }
      defer { self.task = nil }
      await self.loader.refresh(force: force) {
        self.fixtureAttempts += 1
        try await Task.sleep(nanoseconds: 1_000_000_000)
        if self.fixtureAttempts == 1 { throw URLError(.notConnectedToInternet) }
        let release = PublicContentRelease(schemaVersion: 1, version: String(repeating: "a", count: 64),
          catalogJSON: #"{"items":[],"lessons":[],"categories":[]}"#, images: [])
        apply(try Self.catalog(release))
        return release
      }
    }
  }
  #endif

  init(directory: URL, enabled: Bool) {
    cache = PublicContentCache(directory: directory.appendingPathComponent("PublicContent"))
    worker = PublicContentWorker(cache: cache)
    var initial: PublicContentRelease?
    if enabled, let release = cache.load(), (try? Self.catalog(release)) != nil {
      initial = release
      PublicContentImages.files = cache.imageURLs(release: release)
    } else {
      PublicContentImages.files = [:]
    }
    #if DEBUG
    // Explicit test-runner input only. Never read a fixture from the application bundle,
    // persist it as a cloud release, or enable this route in the shipping configuration.
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-testing"), arguments.contains("--ui-testing-external-catalog"),
       let json = ProcessInfo.processInfo.environment["COAST_UI_TEST_CATALOG"],
       let names = try? PublicContentRelease.referencedImages(in: Data(json.utf8)) {
      let version = PublicContentRelease.digest(Data(json.utf8))
      let fixture = PublicContentRelease(schemaVersion: 1, version: version, catalogJSON: json,
        images: names.sorted().map {
          PublicContentImage(name: $0, path: "content/\(version)/images/\($0).jpg",
            sha256: PublicContentRelease.digest(Data([0])), bytes: 1)
        })
      if (try? Self.catalog(fixture)) != nil {
        initial = fixture
        PublicContentImages.files = [:]
      }
    }
    #endif
    loader = PublicContentLoader(cached: initial)
    loader.onChange = { NotificationCenter.default.post(name: Self.changed, object: nil) }
  }

  static func catalog(_ release: PublicContentRelease) throws -> Catalog {
    try release.validate()
    return try JSONDecoder().decode(Catalog.self, from: Data(release.catalogJSON.utf8))
  }

  @MainActor func refresh(force: Bool = false, identity: @escaping @MainActor () async throws -> String,
                          apply: @escaping @MainActor (Catalog) -> Void) {
    guard task == nil else { return }
    task = Task { [weak self] in
      guard let self else { return }
      defer { self.task = nil }
      await self.loader.refresh(force: force) {
        _ = try await identity()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config, delegate: PublicContentRedirectGuard(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let release = try await PublicContentREST.fetch(token: { forceRefresh in
          guard let user = Auth.auth().currentUser else { throw PublicContentREST.Failure.invalidToken }
          return try await user.getIDToken(forcingRefresh: forceRefresh)
        }, send: { request in
          let (stream, response) = try await session.bytes(for: request)
          guard let http = response as? HTTPURLResponse, response.url == request.url else {
            throw PublicContentREST.Failure.invalidDocument
          }
          guard http.statusCode == 200 else { return (http.statusCode, Data()) }
          guard response.expectedContentLength <= Int64(PublicContentREST.maximumResponseBytes) else {
            throw PublicContentREST.Failure.invalidDocument
          }
          var data = Data()
          for try await byte in stream {
            try Task.checkCancellation()
            guard data.count < PublicContentREST.maximumResponseBytes else {
              throw PublicContentREST.Failure.invalidDocument
            }
            data.append(byte)
          }
          return (http.statusCode, data)
        })
        let catalog = try Self.catalog(release)
        #if DEBUG
        print("[PublicContent] REST catalog received and validated")
        #endif
        if self.current == release { return release }
        let files = try await self.worker.fetchAndInstall(release, fetch: { image in
          let url = URL(string: "https://coast-wild-20260915.web.app/\(image.path)")!
          // Use streaming bytes so a malformed response cannot allocate an unbounded body.
          let (stream, response) = try await session.bytes(from: url)
          guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                response.url == url, response.expectedContentLength <= Int64(image.bytes)
          else { throw PublicContentError.invalidImage }
          var data = Data(); data.reserveCapacity(image.bytes)
          for try await byte in stream {
            try Task.checkCancellation()
            guard data.count < image.bytes else { throw PublicContentError.invalidImage }
            data.append(byte)
          }
          return data
        }, validateImage: { data in
          guard let decoded = UIImage(data: data) else { return false }
          return decoded.size.width <= 8192 && decoded.size.height <= 8192
        })
        PublicContentImages.files = files
        apply(catalog)
        return release
      }
    }
  }
}
