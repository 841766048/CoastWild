import Foundation

enum LearningRequestError: LocalizedError, Equatable {
  case notFound
  case simulatedFailure

  var errorDescription: String? {
    switch self {
    case .notFound: return "learning.notFound"
    case .simulatedFailure: return "learning.requestFailed"
    }
  }
}

final class LearningRepository {
  private var lessons: [CoastLesson]
  private let delayNanoseconds: ClosedRange<UInt64>
  private let shouldFail: @Sendable () -> Bool

  init(
    lessons: [CoastLesson],
    delayNanoseconds: ClosedRange<UInt64> = 650_000_000...1_100_000_000,
    shouldFail: @escaping @Sendable () -> Bool = { false }
  ) {
    self.lessons = lessons
    self.delayNanoseconds = delayNanoseconds
    self.shouldFail = shouldFail
  }

  func lessons(category: String) async throws -> [CoastLesson] {
    try await waitForResponse()
    return lessons.filter { $0.category == category }
  }

  func replaceLessons(_ value: [CoastLesson]) { lessons = value }

  func lesson(id: String) async throws -> CoastLesson {
    try await waitForResponse()
    guard let lesson = lessons.first(where: { $0.key == id }) else {
      throw LearningRequestError.notFound
    }
    return lesson
  }

  private func waitForResponse() async throws {
    let delay = UInt64.random(in: delayNanoseconds)
    if delay > 0 { try await Task.sleep(nanoseconds: delay) }
    try Task.checkCancellation()
    if shouldFail() { throw LearningRequestError.simulatedFailure }
  }
}
