import UIKit
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager
import IQKeyboardToolbar

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  var coast: CoastEnvironment?
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    IQKeyboardManager.shared.isEnabled = true
    IQKeyboardManager.shared.resignOnTouchOutside = true
    IQKeyboardManager.shared.keyboardDistance = 12
    IQKeyboardToolbarManager.shared.isEnabled = true
    let window = UIWindow(frame: UIScreen.main.bounds)
    self.window = window
    window.tintColor = CoastStyle.brand
    do {
      let environment = try CoastEnvironment()
      coast = environment
      environment.window = window
      environment.showRoot()
    } catch {
      let vc = UIViewController()
      vc.view.backgroundColor = .systemBackground
      let label = UILabel()
      label.numberOfLines = 0
      label.text =
        "无法打开本地数据，请重新启动。\nUnable to open local data. Please restart.\n\(error.localizedDescription)"
      label.frame = CGRect(x: 30, y: 150, width: window.bounds.width - 60, height: 240)
      vc.view.addSubview(label)
      window.rootViewController = vc
    }
    window.makeKeyAndVisible()
    return true
  }
}
final class CoastEnvironment {
  let integration: IntegrationEnvironment
  let integrationRuntime: IntegrationRuntimeConfiguration
  let deviceIdentity: DeviceIdentityStore
  let remoteSessions: RemoteSessionStore
  let integrationAPI: IntegrationAPIClient
  let remoteSessionCoordinator: RemoteSessionCoordinator
  let store: CoastStore
  let vault: AccountVault
  let catalog: Catalog
  let directory: URL
  weak var window: UIWindow?
  var chinese: Bool { store.preferences.language != "en" }
  init() throws {
    guard let integrationURL = Bundle.main.url(
      forResource: "IntegrationConfig",
      withExtension: "plist"
    ) else {
      throw IntegrationEnvironmentLoader.LoadError.invalidPropertyList
    }
    integration = try IntegrationEnvironmentLoader.load(
      propertyListData: Data(contentsOf: integrationURL),
      bundleIdentifier: Bundle.main.bundleIdentifier ?? ""
    )
    integrationRuntime = IntegrationRuntimeConfiguration(environment: integration)
    let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
    let defaults = testing
      ? UserDefaults(suiteName: "com.coastwild.integration.ui-tests")!
      : UserDefaults.standard
    if testing && ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
      defaults.removePersistentDomain(forName: "com.coastwild.integration.ui-tests")
    }
    deviceIdentity = DeviceIdentityStore(
      bundleIdentifier: integration.bundleIdentifier,
      defaults: defaults
    )
    let deviceID = try deviceIdentity.resolve()
    remoteSessions = RemoteSessionStore(defaults: defaults)
    let contextProvider = RequestContextProvider(values: RequestContextValues(
      deviceID: deviceID,
      model: UIDevice.current.model,
      language: Locale.preferredLanguages.first ?? "en",
      appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
      bundleIdentifier: integration.bundleIdentifier,
      timeZone: TimeZone.current.identifier,
      country: Locale.current.region?.identifier ?? "",
      platformVersion: UIDevice.current.systemVersion,
      localeIdentifier: Locale.current.identifier,
      attributionSDK: "AJ",
      adjustSDKVersion: "0.0.0"
    ))
    integrationAPI = IntegrationAPIClient(
      primaryHost: integration.primaryHost,
      contextProvider: contextProvider,
      keyStore: IntegrationKeyStore(),
      runtimeConfiguration: integrationRuntime
    )
    remoteSessionCoordinator = RemoteSessionCoordinator(
      api: integrationAPI,
      deviceIdentity: deviceIdentity,
      sessions: remoteSessions
    )
    directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(testing ? "CoastWildTests" : "CoastWild")
    vault = try AccountVault(testing: testing)
    if testing && ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
      if FileManager.default.fileExists(atPath: directory.path) {
        try FileManager.default.removeItem(at: directory)
      }
      try vault.clearTestVault()
    }
    let existed = FileManager.default.fileExists(atPath: directory.path)
    store = try CoastStore(directory: directory)
    if !existed && !testing {
      var prefs = store.preferences
      prefs.language = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh-Hans" : "en"
      prefs.region = Locale.current.region?.identifier == "CN" ? "CN" : "US"
      prefs.distanceUnit = prefs.region == "CN" ? "km" : "mi"
      prefs.temperatureUnit = prefs.region == "CN" ? "c" : "f"
      try store.updatePreferences(prefs)
    }
    let url = Bundle.main.url(forResource: "catalog", withExtension: "json")!
    catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    try store.activate(accountID: vault.current?.id)
  }
  func t(_ en: String, _ zh: String) -> String { chinese ? zh : en }
  func text(_ value: [String: String]) -> String {
    value[chinese ? "zh-Hans" : "en"] ?? value["en"] ?? ""
  }
  func item(_ id: String) -> CoastContent? { catalog.items.first { $0.key == id } }
  func category(_ key: String) -> String {
    ["surf": t("Surf", "冲浪"), "hike": t("Hiking", "徒步"), "camp": t("Camping", "露营")][key] ?? key
  }
  @MainActor func showRoot() {
    IQKeyboardToolbarManager.shared.toolbarConfiguration.doneBarButtonConfiguration =
      IQBarButtonItemConfiguration(title: t("Done", "完成"))
    if vault.current != nil && store.accountID != nil {
      let tabs = UITabBarController()
      let controllers: [(UIViewController, String, String)] = [
        (ExploreController(self), t("Explore", "探索"), "search"),
        (LearnController(self), t("Learn", "学习"), "learn"),
        (TripsController(self), t("Trips", "出游"), "trips"),
        (JournalController(self), t("Journal", "手记"), "journal"),
      ]
      tabs.viewControllers = controllers.map { vc, name, icon in
        let nav = navigation(vc)
        nav.tabBarItem = UITabBarItem(
          title: name, image: UIImage(named: "icon-" + icon),
          selectedImage: UIImage(named: "icon-" + icon))
        return nav
      }
      let appearance = UITabBarAppearance()
      appearance.configureWithOpaqueBackground()
      appearance.backgroundColor = .white
      tabs.tabBar.standardAppearance = appearance
      tabs.tabBar.scrollEdgeAppearance = appearance
      tabs.tabBar.tintColor = CoastStyle.brand
      tabs.tabBar.unselectedItemTintColor = UIColor(hex: 0x46525B)
      for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
        item.normal.iconColor = UIColor(hex: 0x46525B)
        item.selected.iconColor = CoastStyle.brand
        item.normal.titleTextAttributes = [.font: CoastStyle.font(10), .foregroundColor: UIColor(hex: 0x46525B)]
        item.selected.titleTextAttributes = [.font: CoastStyle.font(10, .semibold), .foregroundColor: CoastStyle.brand]
      }
      tabs.tabBar.standardAppearance = appearance
      tabs.tabBar.scrollEdgeAppearance = appearance
      window?.rootViewController = tabs
    } else {
      window?.rootViewController = navigation(
        store.preferences.onboardingDone
          ? AuthController(self, mode: .login) : WelcomeController(self))
    }
  }
  func navigation(_ vc: UIViewController) -> UINavigationController {
    let nav = CoastNavigationController(rootViewController: vc)
    nav.navigationBar.tintColor = CoastStyle.brand
    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = .white
    appearance.shadowColor = .clear
    appearance.titleTextAttributes = [.foregroundColor: CoastStyle.ink, .font: CoastStyle.font(17, .bold)]
    nav.navigationBar.standardAppearance = appearance
    nav.navigationBar.scrollEdgeAppearance = appearance
    nav.navigationBar.prefersLargeTitles = false
    return nav
  }
  @MainActor func authenticated() throws {
    try store.activate(accountID: vault.current?.id)
    var prefs = store.preferences
    prefs.onboardingDone = true
    try store.updatePreferences(prefs)
    showRoot()
  }
  @MainActor func logout() throws {
    try vault.logout()
    try store.activate(accountID: nil)
    showRoot()
  }
  func photoURL(_ filename: String) -> URL {
    directory.appendingPathComponent("Photos").appendingPathComponent(store.accountID ?? "none")
      .appendingPathComponent(URL(fileURLWithPath: filename).lastPathComponent)
  }
  func photo(_ filename: String) -> UIImage? { UIImage(contentsOfFile: photoURL(filename).path) }
  func cleanUnusedPhotos() {
    let folder = photoURL("unused").deletingLastPathComponent()
    let used = store.ledger.referencedPhotoFilenames
    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: nil)
    else { return }
    for file in files where !used.contains(file.lastPathComponent) {
      try? FileManager.default.removeItem(at: file)
    }
  }
  func errorText(_ error: Error) -> String {
    let key = error.localizedDescription
    let map: [String: (String, String)] = [
      "auth.credentials": ("Email or password is incorrect.", "邮箱或密码不正确。"),
      "auth.invalid": (
        "Check your email, name and password (at least 10 characters).", "请检查邮箱、昵称与密码（至少 10 个字符）。"
      ), "auth.duplicate": ("This email already has a local account.", "该邮箱已注册本地账号。"),
      "auth.expired": ("Recovery code expired. Request a new code.", "验证码已过期或尝试过多，请重新获取。"),
      "auth.code": ("Incorrect recovery code.", "验证码不正确。"),
      "auth.storage": ("Could not save credentials. Try again.", "账号未能保存，请重试。"),
    ]
    if let value = map[key] { return t(value.0, value.1) }
    let validation: [String: (String, String)] = [
      "account.required": ("Please log in to continue.", "请先登录后继续。"),
      "trip.name.required": ("Enter a trip name.", "请输入出游名称。"),
      "trip.name.tooLong": ("Trip names can have up to 60 characters.", "出游名称最多 60 字。"),
      "trip.notes.tooLong": ("Notes can have up to 1,000 characters.", "备注最多 1000 字。"),
      "trip.date.incomplete": ("Enter both dates or leave both empty.", "请同时填写起止日期，或同时留空。"),
      "trip.date.invalid": ("Enter a valid date as YYYY-MM-DD.", "请输入有效日期，格式为 YYYY-MM-DD。"),
      "trip.date.range": ("End date must be on or after start date.", "结束日期不能早于开始日期。"),
      "trip.date.excludesItems": (
        "Move activities into the new date range before shortening this trip.",
        "缩短日期前，请先调整超出新范围的活动。"
      ),
      "trip.activity.duplicate": ("This experience is already on this day.", "当天已添加此体验。"),
      "trip.activity.dayOutOfRange": ("Choose a day within this trip.", "请选择出游日期范围内的一天。"),
      "trip.activity.time.invalid": (
        "Enter a time as HH:mm or leave it empty.", "请输入 HH:mm 格式的时间，或留空。"
      ),
      "entry.title.tooLong": ("Titles can have up to 80 characters.", "手记标题最多 80 字。"),
      "entry.body.tooLong": ("Entries can have up to 10,000 characters.", "手记正文最多 10000 字。"),
      "entry.photos.tooMany": ("You can add up to 12 photos.", "最多可以添加 12 张照片。"),
      "entry.content.required": ("Add some text or a photo.", "请填写正文或添加照片。"),
      "entry.date.invalid": ("Enter a valid journal date.", "请输入有效的手记日期。"),
      "entry.trip.notFound": (
        "The linked trip is no longer available. Choose another trip.", "关联出游已不可用，请重新选择。"
      ),
    ]
    if let value = validation[key] { return t(value.0, value.1) }
    return t(
      "Could not save. Check your input and try again. Your edits are retained.",
      "未能保存，请检查输入后重试。你的编辑内容已保留。")
  }
}

/// Keep root page titles in the content, as specified by HF-v1.2.
final class CoastNavigationController: UINavigationController, UINavigationControllerDelegate {
  override func viewDidLoad() { super.viewDidLoad(); delegate = self }
  func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
    let root = viewController is ExploreController || viewController is LearnController || viewController is TripsController || viewController is JournalController || viewController is WelcomeController
    setNavigationBarHidden(root, animated: animated)
  }
}
