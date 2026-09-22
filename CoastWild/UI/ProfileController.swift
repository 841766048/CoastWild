import UIKit

final class ProfileController: CoastController {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset(); title = env.t("Your space", "个人空间"); navigationItem.backButtonTitle = title
    contentTop.constant = 31; stack.spacing = 16
    let avatar = accountPortrait(env, size: 27); add(avatar); stack.setCustomSpacing(12, after: avatar)
    add(coastStats([
      ("\(env.store.ledger.trips.count)", env.t("Trips", "出游")),
      ("\(env.store.ledger.entries.filter { !$0.isDraft }.count)", env.t("Entries", "手记")),
      ("\(env.store.ledger.progress.values.filter { $0.completed }.count)", env.t("Lessons", "已学课程"))
    ]))
    add(coastPanel([
      coastSettingRow(env.t("My account", "我的账号"), icon: "user") { [weak self] in
        guard let self else { return }; self.push(AccountController(self.env))
      },
      coastSettingRow(env.t("Your trail", "足迹"), icon: "trips") { [weak self] in
        guard let self else { return }; self.push(TrailController(self.env))
      },
      coastSettingRow(env.t("Saved", "收藏"), value: "\(env.store.ledger.bookmarks.count)", icon: "bookmark") { [weak self] in
        guard let self else { return }; self.push(BookmarksController(self.env))
      },
      coastSettingRow(env.t("Preferences", "偏好设置"), icon: "settings") { [weak self] in
        guard let self else { return }; self.push(PreferencesController(self.env))
      },
      coastSettingRow(
        env.t("Reminders", "提醒与通知"),
        value: env.store.ledger.reminderPlan.tripEnabled
          || env.store.ledger.reminderPlan.journalEnabled
          ? env.t("On", "已开启") : env.t("Off", "未开启"),
        icon: "clock"
      ) { [weak self] in
        guard let self else { return }; self.push(RemindersController(self.env))
      },
      coastSettingRow(env.t("Data & privacy", "数据与隐私"), icon: "shield") { [weak self] in
        guard let self else { return }; self.push(PrivacyController(self.env))
      }
    ], spacing: 0, inset: 0))
    add(coastNotice(env.t("Data stays on this device, in your own account space.", "数据保存在此设备中，每个账号使用独立空间。")))
  }
}
final class AccountController: CoastController {
  override func viewDidLoad() {
    super.viewDidLoad(); title = nil; contentTop.constant = 31; stack.spacing = 28
    add(accountPortrait(env, size: 32))
    note(env.t("Trips and journals are saved on this device for this account. Logging out keeps them for your next visit.", "出游与手记分开保存在此设备的当前账号下。退出不会删除它们，下次登录可以继续查看。"))
    add(coastButton(env.t("Log out", "退出登录"), secondary: true) { [weak self] in
      guard let self else { return }; _ = self.save { try self.env.logout() }
    })
    add(coastLabel(env.t("Your account is stored on this device. No email is sent.", "账号保存在此设备上，不会发送邮件。"), size: 11, color: CoastStyle.muted))
  }
}
final class PreferencesController: CoastController {
  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }
  func render() {
    reset(); title = nil; contentTop.constant = 27; view.backgroundColor = UIColor(hex: 0xF3F8FA)
    heading(env.t("Preferences", "偏好设置"))
    add(coastLabel(env.t("Language, content region and units can be set separately.", "语言、内容地区与计量单位可以分别设置。"), size: 14, color: CoastStyle.muted))
    stack.setCustomSpacing(10, after: stack.arrangedSubviews[0])
    stack.setCustomSpacing(20, after: stack.arrangedSubviews[1])
    let fields = UIStackView(); fields.axis = .vertical; fields.spacing = 18
    @discardableResult func choice(_ label: String, value: String, values: [String], selectedValue: String? = nil, selected: @escaping (Int) -> Void) -> UIButton {
      let group = UIStackView(); group.axis = .vertical; group.spacing = 8
      group.addArrangedSubview(coastLabel(label, size: 14))
      let control = UIButton(type: .system); var config = UIButton.Configuration.plain()
      config.title = value
      config.baseForegroundColor = CoastStyle.ink
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var attributes = incoming; attributes.font = CoastStyle.font(14); return attributes
      }
      config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 40)
      control.configuration = config; control.contentHorizontalAlignment = .leading
      control.backgroundColor = CoastStyle.inputFill; control.layer.cornerRadius = 9
      control.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
      let chevron = UIImageView(image: UIImage(named: "icon-down")); chevron.tintColor = CoastStyle.muted
      chevron.contentMode = .scaleAspectFit; chevron.isUserInteractionEnabled = false; chevron.translatesAutoresizingMaskIntoConstraints = false
      control.addSubview(chevron); NSLayoutConstraint.activate([
        chevron.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12),
        chevron.centerYAnchor.constraint(equalTo: control.centerYAnchor),
        chevron.widthAnchor.constraint(equalToConstant: 18), chevron.heightAnchor.constraint(equalToConstant: 18)
      ])
      control.showsMenuAsPrimaryAction = true
      control.menu = UIMenu(children: values.enumerated().map { i, text in
        UIAction(title: text, state: (selectedValue ?? value) == text ? .on : .off) { _ in selected(i) }
      }); group.addArrangedSubview(control); fields.addArrangedSubview(group); return control
    }
    choice(env.t("Language", "语言"), value: env.chinese ? "简体中文" : "English", values: ["English", "简体中文"]) { [weak self] i in
      guard let self else { return }; self.update { $0.language = i == 0 ? "en" : "zh-Hans" }; self.env.showRoot()
    }
    choice(env.t("Region", "地区"), value: env.store.preferences.region == "CN" ? env.t("Mainland China", "中国大陆") : env.t("United States", "美国"), values: [env.t("United States", "美国"), env.t("Mainland China", "中国大陆")]) { [weak self] i in self?.update { $0.region = i == 0 ? "US" : "CN" } }
    let selectedDistance = env.store.preferences.distanceUnit == "km" ? env.t("Kilometers", "公里") : env.t("Miles", "英里")
    let units = choice(env.t("Units", "单位"), value: selectedDistance + " · " + (env.store.preferences.temperatureUnit == "c" ? "°C" : "°F"), values: [env.t("Kilometers", "公里"), env.t("Miles", "英里")], selectedValue: selectedDistance) { [weak self] i in self?.update { $0.distanceUnit = i == 0 ? "km" : "mi" } }
    let form = coastFormPanel([fields]); add(form); stack.setCustomSpacing(24, after: form)
    let temperature = UIMenu(title: env.t("Temperature", "温度单位"), children: [
      UIAction(title: "°C", state: env.store.preferences.temperatureUnit == "c" ? .on : .off) { [weak self] _ in self?.update { $0.temperatureUnit = "c" } },
      UIAction(title: "°F", state: env.store.preferences.temperatureUnit == "f" ? .on : .off) { [weak self] _ in self?.update { $0.temperatureUnit = "f" } }
    ])
    units.menu = UIMenu(children: (units.menu?.children ?? []) + [temperature])
    let interestTitle = coastLabel(env.t("Your interests", "你的兴趣"), size: 18, weight: .bold); add(interestTitle); stack.setCustomSpacing(26, after: interestTitle)
    let chips = UIStackView(); chips.axis = .horizontal; chips.spacing = 8
    for key in env.categoryKeys {
      let selected = (env.store.preferences.interests ?? env.categoryKeys).contains(key)
      let chip = UIButton(type: .system); chip.setTitle(env.category(key), for: .normal)
      chip.titleLabel?.font = CoastStyle.font(14); chip.setTitleColor(selected ? .white : CoastStyle.ink, for: .normal)
      chip.backgroundColor = selected ? CoastStyle.brand : CoastStyle.field; chip.layer.cornerRadius = 20
      chip.widthAnchor.constraint(greaterThanOrEqualToConstant: 62).isActive = true
      chip.heightAnchor.constraint(equalToConstant: 40).isActive = true
      chip.addAction(UIAction { [weak self] _ in self?.update { p in
        var values = p.interests ?? self?.env.categoryKeys ?? []
        if values.contains(key) { values.removeAll { $0 == key } } else { values.append(key) }; p.interests = values
      } }, for: .touchUpInside); chips.addArrangedSubview(chip)
    }
    chips.addArrangedSubview(UIView()); add(chips)
    stack.setCustomSpacing(8, after: chips)
    add(coastNotice(env.t("Settings save automatically. Trips and journal entries stay as you wrote them.", "设置自动保存。出游与手记内容会保持你书写时的原样。")))
  }
  func update(_ change: (inout CoastPreferences) -> Void) {
    var prefs = env.store.preferences; change(&prefs)
    if save({ try env.store.updatePreferences(prefs) }) { render() }
  }
}
final class PrivacyController: CoastController {
  override func viewDidLoad() {
    super.viewDidLoad(); title = nil; contentTop.constant = 27; stack.spacing = 16; view.backgroundColor = UIColor(hex: 0xF3F8FA)
    heading(env.t("Data & privacy", "数据与隐私"))
    stack.setCustomSpacing(20, after: stack.arrangedSubviews.last!)
    add(coastFormPanel([
      coastLabel(env.t("Your memories belong to you.", "你的回忆，属于你。"), size: 23, weight: .bold),
      coastLabel(env.t("Trips, saved content and journals stay on this device. Accounts are local and are not uploaded to the cloud.", "出游、收藏与手记保存在此设备上。账号仅在本地使用，不会上传云端。"), size: 16, color: CoastStyle.muted)
    ]))
    add(coastPanel([
      coastSettingRow(env.t("Export my data", "导出我的数据"), icon: "share") { [weak self] in self?.export() },
      coastSettingRow(env.t("Manage saved content", "管理收藏内容"), icon: "bookmark") { [weak self] in
        guard let self else { return }; self.push(BookmarksController(self.env))
      },
      coastSettingRow(env.t("Photo access", "照片访问"), value: env.t("Selected only", "仅所选照片"), icon: "photo") { [weak self] in
        guard let self else { return }; self.message(self.env.t("Only the photos you choose", "只导入你主动选择的照片"), self.env.t("The system picker grants access only to selected photos. Originals remain in your library.", "系统照片选择器仅导入你选中的照片，不读取整个照片库，也不会修改原图。"))
      },
      coastSettingRow(env.t("Clear this space", "清除此空间数据"), icon: "trash", destructive: true) { [weak self] in self?.clear() }
    ], spacing: 0, inset: 0))
    add(coastNotice(env.t("Export includes preferences, progress, trips, journals and imported photos. Keep a copy before clearing data.", "导出包含偏好、学习进度、出游、手记及导入的照片。清除数据前，请先保留副本。")))
    add(coastPanel([
      coastSettingRow(env.t("Terms of Use", "用户协议"), icon: "info") { [weak self] in
        guard let self else { return }
        self.push(LegalWebController(self.env, document: .terms))
      },
      coastSettingRow(env.t("Privacy Policy", "隐私政策"), icon: "shield") { [weak self] in
        guard let self else { return }
        self.push(LegalWebController(self.env, document: .privacy))
      }
    ], spacing: 0, inset: 0))
    stack.setCustomSpacing(0, after: stack.arrangedSubviews.last!)
    add(coastFormPanel([
      coastLabel(env.t("About this app", "关于海岸与山野"), size: 18, weight: .bold),
      coastLabel(env.t("Coast & Wild · HF-v1. Original sample content; no live conditions, bookings or location tracking.", "海岸与山野 · HF-v1。内容与目的地图片用于体验示例，不提供实时环境、预订或位置跟踪。"), size: 13, color: CoastStyle.muted)
    ]))
  }
  func export() {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "CoastWild-export-" + UUID().uuidString)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let ledger = folder.appendingPathComponent("coast-wild.json")
      try env.store.exportData().write(to: ledger, options: .atomic)
      var urls = [ledger]
      // 手记照片与出游封面都算用户数据，缺了任意一类导出就不完整。
      for filename in env.store.ledger.referencedPhotoFilenames.sorted() {
        let source = env.photoURL(filename)
        let destination = folder.appendingPathComponent(filename)
        // 个别照片丢失不该让整次导出失败，其余内容照常带走。
        guard (try? FileManager.default.copyItem(at: source, to: destination)) != nil else {
          continue
        }
        urls.append(destination)
      }
      let share = UIActivityViewController(activityItems: urls, applicationActivities: nil)
      share.popoverPresentationController?.sourceView = view
      share.completionWithItemsHandler = { _, _, _, _ in
        try? FileManager.default.removeItem(at: folder)
      }
      present(share, animated: true)
    } catch {
      try? FileManager.default.removeItem(at: folder)
      self.error(error)
    }
  }
  func clear() {
    confirm(
      env.t("Clear local content?", "清除本地内容？"),
      env.t(
        "This removes this account's trips, entries, saved content and learning progress from this device. Export a copy first. Other accounts are unaffected.",
        "将删除当前账号在此设备上的出游、手记、收藏与学习进度。建议先导出副本，其他账号不受影响。")
    ) { [weak self] in
      guard let self else { return }
      let photoFolder = self.env.photoURL("unused").deletingLastPathComponent()
      if self.save({
        try self.env.store.clearCurrentLedger()
        var preferences = self.env.store.preferences
        preferences.onboardingDone = false
        try self.env.store.updatePreferences(preferences)
        try self.env.logout()
      }) {
        try? FileManager.default.removeItem(at: photoFolder)
        self.env.showRoot()
      }
    }
  }
}

private func accountPortrait(_ env: CoastEnvironment, size: CGFloat) -> UIView {
  let group = UIStackView(); group.axis = .vertical; group.alignment = .center; group.spacing = 10
  let avatar = UIView(); avatar.backgroundColor = UIColor(hex: 0xE3F0F4); avatar.layer.cornerRadius = 43
  avatar.widthAnchor.constraint(equalToConstant: 86).isActive = true; avatar.heightAnchor.constraint(equalToConstant: 86).isActive = true
  let image = UIImageView(image: UIImage(named: "icon-user")); image.tintColor = CoastStyle.brand; image.contentMode = .scaleAspectFit
  image.translatesAutoresizingMaskIntoConstraints = false; avatar.addSubview(image)
  NSLayoutConstraint.activate([image.widthAnchor.constraint(equalToConstant: 39), image.heightAnchor.constraint(equalToConstant: 39), image.centerXAnchor.constraint(equalTo: avatar.centerXAnchor), image.centerYAnchor.constraint(equalTo: avatar.centerYAnchor)])
  group.addArrangedSubview(avatar); group.setCustomSpacing(18, after: avatar)
  let name = coastLabel(env.vault.current?.name ?? "Coast & Wild", size: size, weight: .bold); name.textAlignment = .center
  group.addArrangedSubview(name)
  let email = coastLabel(env.vault.current?.email ?? "", size: 16, color: CoastStyle.muted); email.textAlignment = .center; group.addArrangedSubview(email)
  return group
}
