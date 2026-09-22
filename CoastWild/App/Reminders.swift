import UIKit
import UserNotifications

/// 本机提醒。出发前提醒与每日手记提醒都由系统在本设备发出，
/// 不经过服务器，也不发送邮件。这是本项目唯一需要通知权限的能力。
final class CoastReminders {
  enum Permission {
    case notAsked
    case allowed
    case denied
  }

  static let tripPrefix = "coast.trip."
  static let journalIdentifier = "coast.journal.daily"

  private let center: UNUserNotificationCenter

  init(center: UNUserNotificationCenter = .current()) {
    self.center = center
  }

  func permission() async -> Permission {
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .notDetermined: return .notAsked
    case .denied: return .denied
    default: return .allowed
    }
  }

  /// 首次开启开关时请求授权。被拒绝时返回 false，调用方负责回弹开关并给出引导。
  func request() async -> Bool {
    do {
      return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
      return false
    }
  }

  /// 按当前设置重排全部提醒。每次设置或出游数据变化后整体重建，
  /// 避免残留已删除出游的通知。
  func reschedule(plan: CoastReminderPlan, ledger: CoastLedger, chinese: Bool) async {
    let pending = await center.pendingNotificationRequests()
    let ours = pending.map(\.identifier).filter {
      $0.hasPrefix(Self.tripPrefix) || $0 == Self.journalIdentifier
    }
    center.removePendingNotificationRequests(withIdentifiers: ours)
    guard await permission() == .allowed else { return }

    if plan.tripEnabled {
      for trip in ledger.trips where !trip.completed {
        guard let request = tripRequest(trip, plan: plan, chinese: chinese) else { continue }
        try? await center.add(request)
      }
    }
    if plan.journalEnabled, let request = journalRequest(plan: plan, chinese: chinese) {
      try? await center.add(request)
    }
  }

  func cancelAll() {
    center.removeAllPendingNotificationRequests()
  }

  // MARK: 排程内容

  /// 出发前提醒。触发时刻 = 起始日期 - 提前天数，当天的指定时刻。
  /// 已过去的时刻不排程。
  func tripRequest(
    _ trip: CoastTrip, plan: CoastReminderPlan, chinese: Bool, now: Date = Date(),
    calendar: Calendar = Calendar(identifier: .gregorian)
  ) -> UNNotificationRequest? {
    guard !trip.start.isEmpty, let start = CoastValidation.parseDate(trip.start) else { return nil }
    guard let clock = Self.clockParts(plan.tripTime) else { return nil }
    var local = calendar
    local.timeZone = .current
    // 日期字段是无时区的 ISO 日，按本机时区取当天零点再回退提前天数。
    let startComponents = Calendar(identifier: .gregorian).dateComponents(
      [.year, .month, .day], from: start)
    guard
      let startLocal = local.date(
        from: DateComponents(
          year: startComponents.year, month: startComponents.month, day: startComponents.day)),
      let fireDay = local.date(byAdding: .day, value: -plan.tripLeadDays, to: startLocal),
      let fire = local.date(
        bySettingHour: clock.hour, minute: clock.minute, second: 0, of: fireDay)
    else { return nil }
    guard fire > now else { return nil }

    let content = UNMutableNotificationContent()
    content.title = trip.name
    let left = trip.gearProgress.left
    let lead = plan.tripLeadDays
    let when =
      lead == 0
      ? (chinese ? "今天出发" : "Leaving today")
      : (chinese ? "还有 \(lead) 天出发" : "Leaving in \(lead) day\(lead > 1 ? "s" : "")")
    if plan.includeGearSummary && left > 0 {
      content.body =
        chinese
        ? "\(when)。装备清单还有 \(left) 项未备。"
        : "\(when). \(left) item\(left > 1 ? "s" : "") still to pack."
    } else {
      content.body = chinese ? "\(when)。" : "\(when)."
    }
    content.sound = .default
    let trigger = UNCalendarNotificationTrigger(
      dateMatching: local.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
      repeats: false)
    return UNNotificationRequest(
      identifier: Self.tripPrefix + trip.id, content: content, trigger: trigger)
  }

  func journalRequest(plan: CoastReminderPlan, chinese: Bool) -> UNNotificationRequest? {
    guard let clock = Self.clockParts(plan.journalTime) else { return nil }
    let content = UNMutableNotificationContent()
    content.title = chinese ? "写一篇手记" : "Write an entry"
    content.body =
      chinese ? "留下今天户外的一点记录。" : "Keep a little of today from outside."
    content.sound = .default
    var components = DateComponents()
    components.hour = clock.hour
    components.minute = clock.minute
    return UNNotificationRequest(
      identifier: Self.journalIdentifier, content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
  }

  static func clockParts(_ value: String) -> (hour: Int, minute: Int)? {
    let parts = value.split(separator: ":")
    guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
      (0...23).contains(hour), (0...59).contains(minute)
    else { return nil }
    return (hour, minute)
  }
}
