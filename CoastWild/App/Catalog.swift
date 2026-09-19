import Foundation

struct Catalog: Decodable {
  let items: [CoastContent]
  let lessons: [CoastLesson]
}
struct CoastContent: Decodable {
  let key: String
  let kind: String
  let category: String
  let title: [String: String]
  let subtitle: [String: String]
  let photo: String
  let minutes: Int
  let level: String
  let distanceKm: Double?
  let region: String
  let page: String
  let body: [String: String]?
  var image: String { URL(fileURLWithPath: photo).deletingPathExtension().lastPathComponent }
}
struct CoastLesson: Decodable {
  let key: String
  let category: String
  let title: [String: String]
  let group: [String: String]
  let photo: String
  let steps: [CoastStep]
  var image: String { URL(fileURLWithPath: photo).deletingPathExtension().lastPathComponent }
}
struct CoastStep: Decodable {
  let title: [String: String]
  let body: [String: String]
  let photo: String
  var image: String { URL(fileURLWithPath: photo).deletingPathExtension().lastPathComponent }
}
