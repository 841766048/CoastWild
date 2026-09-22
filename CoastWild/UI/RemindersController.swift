import UIKit
import UserNotifications

/// SE03 提醒与通知。开关、时刻与系统权限状态。
final class RemindersController: CoastController {
  private var reminders: CoastReminders { env.reminders }
  private var permission: CoastReminders.Permission = .notAsked

  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refreshPermission()
  }

  private var plan: CoastReminderPlan { env.store.ledger.reminderPlan }

  private func refreshPermission() {
    Task { @MainActor in
      let next = await reminders.permission()
      let regained = permission != .allowed && next == .allowed
      permission = next
      render()
      // 在系统设置里放开权限后返回，补排一次之前排不了的提醒。
      if regained { env.scheduleReminders() }
    }
  }

  private func render() {
    reset()
    title = env.t("Reminders", "提醒与通知")
    contentTop.constant = 16
    stack.spacing = 12
    let plan = self.plan
    let denied = permission == .denied
    let live = !denied

    add(sectionLabel(env.t("Trip reminders", "出发提醒")))
    add(
      coastPanel(
        [
          switchRow(
            env.t("Remind me before a trip", "出发前提醒"), on: plan.tripEnabled && live,
            identifier: "reminder.trip"
          ) { [weak self] value in self?.setTrip(enabled: value) },
          divider(),
          valueRow(
            env.t("When", "提醒时间"), value: leadText(plan),
            enabled: plan.tripEnabled && live, identifier: "reminder.when"
          ) { [weak self] in self?.pickTripTime() },
          divider(),
          switchRow(
            env.t("Include unpacked items", "包含未备物品"),
            note: env.t(
              "Shows how many checklist items are still open.", "提醒中显示装备清单未完成的数量。"),
            on: plan.includeGearSummary && plan.tripEnabled && live,
            enabled: plan.tripEnabled && live, identifier: "reminder.summary"
          ) { [weak self] value in self?.setSummary(value) },
        ], spacing: 0, inset: 0))

    add(sectionLabel(env.t("Journal reminders", "手记提醒")))
    add(
      coastPanel(
        [
          switchRow(
            env.t("Daily journal nudge", "每日记录提醒"), on: plan.journalEnabled && live,
            identifier: "reminder.journal"
          ) { [weak self] value in self?.setJournal(enabled: value) },
          divider(),
          valueRow(
            env.t("When", "提醒时间"), value: plan.journalTime,
            enabled: plan.journalEnabled && live, identifier: "reminder.journal.when"
          ) { [weak self] in self?.pickJournalTime() },
        ], spacing: 0, inset: 0))

    add(sectionLabel(env.t("System permission", "系统权限")))
    add(
      coastPanel(
        [
          permissionRow(),
          divider(),
          coastSettingRow(
            env.t("Manage in system settings", "在系统设置中管理"), icon: "settings"
          ) {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
          },
        ], spacing: 0, inset: 0))

    if denied {
      let warning = coastLabel(
        env.t(
          "Notifications are turned off for this app, so reminders cannot be sent. Turn them on in system settings, then come back.",
          "该应用的通知已被关闭，暂时无法发送提醒。请在系统设置中开启后返回。"),
        size: 13, color: CoastStyle.red)
      add(warning)
    }
    add(
      coastNotice(
        env.t(
          "Reminders are sent by this device only. No server is involved and no email is sent. Turning the system permission off stops reminders; your trips and checklists are not affected.",
          "提醒仅由本机系统发出，不经过服务器，也不发送邮件。关闭系统通知权限后不再提醒，出游与清单数据不受影响。"
        )))
    add(
      coastButton(env.t("Send a test reminder", "发送一条测试提醒"), secondary: true) { [weak self] in
        self?.sendTest()
      })
  }

  // MARK: 视图片段

  private func sectionLabel(_ text: String) -> UILabel {
    coastLabel(
      text.uppercased(), size: 11, weight: .semibold, color: CoastStyle.brand, letterSpacing: 1.7)
  }

  private func divider() -> UIView {
    let holder = UIView()
    let line = UIView()
    line.backgroundColor = CoastStyle.border
    line.translatesAutoresizingMaskIntoConstraints = false
    holder.addSubview(line)
    NSLayoutConstraint.activate([
      line.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: 14),
      line.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
      line.topAnchor.constraint(equalTo: holder.topAnchor),
      line.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
      holder.heightAnchor.constraint(equalToConstant: 1),
    ])
    return holder
  }

  private func leadText(_ plan: CoastReminderPlan) -> String {
    let lead = plan.tripLeadDays
    if lead == 0 { return env.t("On the day · \(plan.tripTime)", "出发当天 \(plan.tripTime)") }
    return env.t(
      "\(lead) day\(lead > 1 ? "s" : "") before · \(plan.tripTime)",
      "出发前 \(lead) 天 \(plan.tripTime)")
  }

  private func switchRow(
    _ title: String, note: String? = nil, on: Bool, enabled: Bool = true, identifier: String,
    onChange: @escaping (Bool) -> Void
  ) -> UIView {
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 12
    row.alignment = .center
    row.isLayoutMarginsRelativeArrangement = true
    row.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
    let text = UIStackView()
    text.axis = .vertical
    text.spacing = 4
    text.addArrangedSubview(coastLabel(title, size: 16, weight: .medium))
    if let note {
      text.addArrangedSubview(coastLabel(note, size: 12, color: CoastStyle.muted))
    }
    row.addArrangedSubview(text)
    let toggle = UISwitch()
    toggle.isOn = on
    toggle.isEnabled = enabled
    toggle.onTintColor = CoastStyle.brand
    toggle.accessibilityIdentifier = identifier
    toggle.accessibilityLabel = title
    toggle.addAction(
      UIAction { action in
        guard let view = action.sender as? UISwitch else { return }
        onChange(view.isOn)
      }, for: .valueChanged)
    row.addArrangedSubview(toggle)
    row.alpha = enabled ? 1 : 0.42
    row.heightAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
    return row
  }

  private func valueRow(
    _ title: String, value: String, enabled: Bool, identifier: String,
    action: @escaping () -> Void
  ) -> UIView {
    let button = coastSettingRow(title, value: value, action: action)
    button.isEnabled = enabled
    button.alpha = enabled ? 1 : 0.42
    button.accessibilityIdentifier = identifier
    return button
  }

  private func permissionRow() -> UIView {
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 12
    row.alignment = .center
    row.isLayoutMarginsRelativeArrangement = true
    row.layoutMargins = UIEdgeInsets(top: 17, left: 14, bottom: 17, right: 14)
    let icon = UIImageView(image: UIImage(named: "icon-shield"))
    icon.tintColor = CoastStyle.brand
    icon.contentMode = .scaleAspectFit
    icon.widthAnchor.constraint(equalToConstant: 21).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 24).isActive = true
    row.addArrangedSubview(icon)
    row.addArrangedSubview(
      coastLabel(env.t("Notification permission", "系统通知权限"), size: 16, weight: .medium))
    row.addArrangedSubview(UIView())
    let status: String
    let color: UIColor
    switch permission {
    case .allowed:
      status = env.t("Allowed", "已允许")
      color = CoastStyle.brand
    case .denied:
      status = env.t("Denied", "已拒绝")
      color = CoastStyle.red
    case .notAsked:
      status = env.t("Not set", "未设置")
      color = CoastStyle.muted
    }
    let label = coastLabel(status, size: 15, weight: .semibold, color: color)
    label.accessibilityIdentifier = "reminder.permission"
    row.addArrangedSubview(label)
    row.heightAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
    return row
  }

  // MARK: 操作

  /// 开启任一提醒前先确认系统授权。被拒绝时不写入设置，开关回弹并给出引导。
  private func enable(_ apply: @escaping (inout CoastReminderPlan) -> Void) {
    Task { @MainActor in
      switch await reminders.permission() {
      case .denied:
        render()
        message(
          env.t("Notifications are off", "通知已关闭"),
          env.t(
            "This app cannot send reminders until notifications are allowed in system settings. Your trips and checklists are unaffected.",
            "在系统设置里允许通知之前，无法发送提醒。出游与清单数据不受影响。"))
        return
      case .notAsked:
        let granted = await reminders.request()
        permission = granted ? .allowed : .denied
        if !granted {
          render()
          message(
            env.t("Notifications are off", "通知已关闭"),
            env.t(
              "Reminders need notification permission. You can turn it on later in system settings.",
              "提醒需要通知权限。你可以稍后在系统设置中开启。"))
          return
        }
      case .allowed:
        permission = .allowed
      }
      commit(apply)
    }
  }

  private func commit(_ apply: (inout CoastReminderPlan) -> Void) {
    var next = plan
    apply(&next)
    guard save({ try env.store.updateReminders(next) }) else {
      render()
      return
    }
    // 重排由 CoastEnvironment 统一在账本变更后处理。
    render()
  }

  private func setTrip(enabled: Bool) {
    if enabled {
      enable { $0.tripEnabled = true }
    } else {
      commit { $0.tripEnabled = false }
    }
  }

  private func setJournal(enabled: Bool) {
    if enabled {
      enable { $0.journalEnabled = true }
    } else {
      commit { $0.journalEnabled = false }
    }
  }

  private func setSummary(_ value: Bool) {
    commit { $0.includeGearSummary = value }
  }

  private func pickTripTime() {
    let current = plan
    menu(
      env.t("How early", "提前多久"),
      choices: [0, 1, 2, 3, 7].map { days in
        (
          days == 0
            ? env.t("On the day", "出发当天")
            : env.t("\(days) day\(days > 1 ? "s" : "")", "\(days) 天"),
          { [weak self] in
            self?.commit { $0.tripLeadDays = days }
            self?.pickClock(initial: current.tripTime) { value in
              self?.commit { $0.tripTime = value }
            }
          }
        )
      })
  }

  private func pickJournalTime() {
    pickClock(initial: plan.journalTime) { [weak self] value in
      self?.commit { $0.journalTime = value }
    }
  }

  /// 复用出游与手记表单已在用的同一套中英文滚轮选择器。
  private func pickClock(initial: String, onPick: @escaping (String) -> Void) {
    CoastDatePicker.show(
      from: self, title: env.t("Time", "时刻"), value: initial, time: true
    ) { value in
      guard !value.isEmpty else { return }
      onPick(value)
    }
  }

  private func sendTest() {
    Task { @MainActor in
      switch await reminders.permission() {
      case .allowed:
        break
      case .denied:
        message(
          env.t("Notifications are off", "通知已关闭"),
          env.t(
            "Allow notifications in system settings to receive reminders.",
            "请在系统设置中允许通知后再试。"))
        return
      case .notAsked:
        guard await reminders.request() else {
          permission = .denied
          render()
          message(
            env.t("Notifications are off", "通知已关闭"),
            env.t(
              "Reminders need notification permission.", "提醒需要通知权限。"))
          return
        }
        permission = .allowed
        render()
      }
      let left = env.store.ledger.trips.filter { !$0.completed }
        .reduce(0) { $0 + $1.gearProgress.left }
      let content = UNMutableNotificationContent()
      content.title = env.t("Test reminder", "测试提醒")
      content.body =
        plan.includeGearSummary && left > 0
        ? env.t(
          "\(left) item\(left > 1 ? "s" : "") still to pack across your trips.",
          "你的出游里还有 \(left) 项装备未备。")
        : env.t(
          "Reminders are working on this device.", "提醒在本机可以正常发送。")
      content.sound = .default
      let request = UNNotificationRequest(
        identifier: "coast.test." + UUID().uuidString, content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
      try? await UNUserNotificationCenter.current().add(request)
      message(
        env.t("Test reminder sent", "测试提醒已发送"),
        env.t(
          "It arrives in about five seconds. Leave the app to see it on the lock screen.",
          "大约五秒后送达。可以退到后台在锁屏上查看。"))
    }
  }
}
