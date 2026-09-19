import UIKit

final class ProfileController: CoastController {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset()
    title = env.t("Your space", "个人空间")
    let image = UIImageView(image: UIImage(named: "icon-user"))
    image.contentMode = .scaleAspectFit
    image.tintColor = CoastStyle.brand
    image.heightAnchor.constraint(equalToConstant: 72).isActive = true
    add(image)
    heading(env.vault.current?.name ?? "Coast & Wild")
    note(env.t("Make more room for outside.", "为户外多留一点时间。"))
    add(
      coastLabel(
        "\(env.store.ledger.trips.count) " + env.t("Trips", "次出游")
          + "    \(env.store.ledger.entries.filter{!$0.isDraft}.count) " + env.t("Entries", "篇手记")
          + "    \(env.store.ledger.progress.values.filter{$0.completed}.count) "
          + env.t("Lessons", "个已学专题"), size: 16, weight: .medium))
    add(
      row(title: env.t("My account", "我的账号"), subtitle: env.vault.current?.email) { [weak self] in
        guard let self else { return }
        self.push(AccountController(self.env))
      })
    add(
      row(title: env.t("Saved content", "收藏")) { [weak self] in
        guard let self else { return }
        self.push(BookmarksController(self.env))
      })
    add(
      row(title: env.t("Preferences", "偏好设置")) { [weak self] in
        guard let self else { return }
        self.push(PreferencesController(self.env))
      })
    add(
      row(title: env.t("Data & privacy", "数据与隐私")) { [weak self] in
        guard let self else { return }
        self.push(PrivacyController(self.env))
      })
    add(
      row(title: env.t("About Coast & Wild", "关于海岸与山野")) { [weak self] in
        guard let self else { return }
        self.message(
          "Coast & Wild · 1.0",
          self.env.t(
            "Original coastal and outdoor stories. Sample content; not live conditions or navigation. Native local demo.",
            "原创海岸与户外内容。示例内容不提供实时海况或精确导航。当前为原生本地演示版本。"))
      })
  }
}
final class AccountController: CoastController {
  override func viewDidLoad() {
    super.viewDidLoad()
    title = env.t("My account", "我的账号")
    heading(env.vault.current?.name ?? "")
    note(env.vault.current?.email ?? "")
    note(env.t("Local demo account", "本地演示账号"))
    add(
      coastLabel(
        env.t(
          "Your trips, saved content and journals are kept on this device for this account. Logging out keeps them for your next visit.",
          "出游、收藏与手记保存在此设备的当前账号下。退出不会删除数据，下次登录可以继续查看。")))
    add(
      coastButton(env.t("Log out", "退出登录"), secondary: true) { [weak self] in
        guard let self else { return }
        _ = self.save { try self.env.logout() }
      })
  }
}
final class PreferencesController: CoastController {
  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }
  func render() {
    reset()
    title = env.t("Preferences", "偏好设置")
    heading(env.t("Make it yours", "偏好设置"))
    note(env.t("Language, region and units are independent.", "语言、内容地区与单位可以独立设置。"))
    add(coastLabel(env.t("Language", "语言"), size: 17, weight: .semibold))
    chips(["English", "简体中文"], selected: env.chinese ? 1 : 0) { [weak self] i in
      guard let self else { return }
      var prefs = self.env.store.preferences
      prefs.language = i == 0 ? "en" : "zh-Hans"
      if self.save({ try self.env.store.updatePreferences(prefs) }) { self.env.showRoot() }
    }
    add(coastLabel(env.t("Content region", "内容地区"), size: 17, weight: .semibold))
    chips(
      [env.t("United States", "美国"), env.t("Mainland China", "中国大陆")],
      selected: env.store.preferences.region == "CN" ? 1 : 0
    ) { [weak self] i in self?.update { $0.region = i == 0 ? "US" : "CN" } }
    add(coastLabel(env.t("Distance", "距离单位"), size: 17, weight: .semibold))
    chips(["km", "mi"], selected: env.store.preferences.distanceUnit == "km" ? 0 : 1) {
      [weak self] i in self?.update { $0.distanceUnit = i == 0 ? "km" : "mi" }
    }
    add(coastLabel(env.t("Temperature", "温度单位"), size: 17, weight: .semibold))
    chips(["°C", "°F"], selected: env.store.preferences.temperatureUnit == "c" ? 0 : 1) {
      [weak self] i in self?.update { $0.temperatureUnit = i == 0 ? "c" : "f" }
    }
    note(
      env.t(
        "The bundled sample catalog is shared across regions. Region-specific verified destinations are not yet included.",
        "当前内置示例内容在两地共用，尚未提供分别核验的真实目的地内容。"))
  }
  func update(_ change: (inout CoastPreferences) -> Void) {
    var prefs = env.store.preferences
    change(&prefs)
    _ = save { try env.store.updatePreferences(prefs) }
  }
}
final class PrivacyController: CoastController {
  override func viewDidLoad() {
    super.viewDidLoad()
    title = env.t("Data & privacy", "数据与隐私")
    heading(env.t("Your memories. Your choice.", "你的回忆，属于你。"))
    note(
      env.t(
        "Your data stays on this device. Export a copy whenever you want.",
        "出游、收藏与手记保存在此设备上。你可以随时导出个人数据。"))
    add(
      row(title: env.t("Photo access", "照片权限")) { [weak self] in
        guard let self else { return }
        self.message(
          self.env.t("Only the photos you choose", "只导入你主动选择的照片"),
          self.env.t(
            "The system photo picker grants access only to selected photos. Original photos remain in your library.",
            "通过系统照片选择器，仅导入你选中的照片，不读取整个照片库，也不会修改原图。"))
      })
    add(
      coastButton(env.t("Export my data", "导出我的数据"), secondary: true) { [weak self] in
        self?.export()
      })
    add(
      coastButton(env.t("Clear local content", "清除本地内容"), secondary: true) { [weak self] in
        self?.clear()
      })
    note(
      env.t(
        "Export includes your current account's ledger and attached photos, never password data. Keep a copy before clearing.",
        "导出包含当前账号的业务数据及附件照片，不包含密码信息。清除前请自行保存副本。"))
  }
  func export() {
    do {
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
        "CoastWild-export-" + UUID().uuidString)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let ledger = folder.appendingPathComponent("coast-wild.json")
      try env.store.exportData().write(to: ledger, options: .atomic)
      var urls = [ledger]
      for filename in Set(env.store.ledger.entries.flatMap { $0.photos }) {
        let source = env.photoURL(filename)
        let destination = folder.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: source, to: destination)
        urls.append(destination)
      }
      let share = UIActivityViewController(activityItems: urls, applicationActivities: nil)
      share.popoverPresentationController?.sourceView = view
      share.completionWithItemsHandler = { _, _, _, _ in
        try? FileManager.default.removeItem(at: folder)
      }
      present(share, animated: true)
    } catch { self.error(error) }
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
      if self.save({ try self.env.store.clearCurrentLedger() }) {
        try? FileManager.default.removeItem(at: photoFolder)
        self.message(
          self.env.t("Cleared", "已清除"),
          self.env.t("Your local content has been cleared.", "当前账号的本地内容已清除。"))
      }
    }
  }
}
