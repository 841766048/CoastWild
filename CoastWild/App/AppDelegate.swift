import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import CryptoKit
import ImageIO
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager
import IQKeyboardToolbar

enum CoastTestMode {
  static var isEnabled: Bool {
    #if DEBUG
    return ProcessInfo.processInfo.arguments.contains("--ui-testing")
    #else
    return false
    #endif
  }
}


/// Firebase identity is device-anonymous; account aliases preserve legacy note partitions.
/// Private images use owner-only child documents; credentials are never stored in documents.
@MainActor final class FirebaseNoteSync {
  static let changed = Notification.Name("CoastWild.notesSyncChanged")
  private let store: CoastStore
  private let deviceID: String
  private let directory: URL
  private var task: Task<Void, Never>?
  private var retry: Task<Void, Never>?
  private var generation = UUID()
  private var activeAccount: String?
  private var paused = false
  private var requested = false
  private(set) var status = "local"
  private lazy var database: Firestore = {
    Firestore.firestore()
  }()

  init(store: CoastStore, deviceID: String, directory: URL) {
    self.store = store; self.deviceID = deviceID; self.directory = directory
  }

  func schedule() {
    guard !paused else { return }
    if activeAccount != store.accountID {
      generation = UUID(); task?.cancel(); task = nil; retry?.cancel()
      activeAccount = store.accountID
    }
    guard let account = activeAccount else { setStatus("local"); return }
    requested = true
    guard task == nil else { return }
    retry?.cancel()
    let epoch = generation
    task = Task { [weak self] in
      guard let self else { return }
      do {
        repeat {
          self.requested = false
          self.setStatus("syncing")
          let uid = try await self.identity()
          try self.check(epoch, account)
          try self.store.prepareNoteSync(scope: uid + "/" + self.deviceID)
          try self.store.prepareNoteImageSync()
          let notes = self.collection(uid: uid, account: account)
          for id in self.store.pendingNoteIDs.sorted() {
            try self.check(epoch, account)
            let entry = self.store.ledger.entries.first { $0.id == id }
            if let entry {
              try await self.upload(entry, to: notes.document(id), epoch: epoch, account: account)
            } else {
              try await self.deleteNote(notes.document(id))
            }
            try self.check(epoch, account)
            try self.store.acknowledgeNote(id: id, uploaded: entry)
          }
          try await self.readAndMergeAll(notes, epoch: epoch, account: account)
          try self.check(epoch, account)
        } while self.requested || !self.store.pendingNoteIDs.isEmpty
        self.setStatus("synced")
      } catch {
        guard self.generation == epoch else { return }
        self.setStatus("pending")
        self.retry = Task { [weak self] in
          do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
          self?.schedule()
        }
      }
      if self.generation == epoch { self.task = nil }
    }
  }

  func identity() async throws -> String {
    if let user = Auth.auth().currentUser { return user.uid }
    throw NSError(domain: "CoastWild.Auth", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Please continue with your device account first."])
  }

  private func collection(uid: String, account: String) -> CollectionReference {
    let partition = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
    return database.collection("users").document(uid).collection("devices").document(deviceID)
      .collection("accounts").document(partition).collection("notes")
  }

  private func check(_ epoch: UUID, _ account: String) throws {
    try Task.checkCancellation()
    guard generation == epoch, store.accountID == account, !paused else { throw CancellationError() }
  }

  private func upload(_ entry: CoastEntry, to note: DocumentReference, epoch: UUID, account: String) async throws {
    let ids = try entry.photos.map(NotePhotoPayload.id)
    try NotePhotoPayload.validateIDs(ids)
    let previous = try await note.getDocument(source: .server)
    let oldIDs = previous.data()?["photoIDs"] as? [String] ?? []
    try NotePhotoPayload.validateIDs(oldIDs)
    try check(epoch, account)
    let batch = database.batch()
    for (filename, id) in zip(entry.photos, ids) where !oldIDs.contains(id) {
      let url = directory.appendingPathComponent("Photos").appendingPathComponent(account).appendingPathComponent(filename)
      let payload = try await Task.detached(priority: .utility) { try NotePhotoCodec.compress(url) }.value
      try check(epoch, account)
      var data = try JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as! [String: Any]
      data["updatedAt"] = FieldValue.serverTimestamp()
      batch.setData(data, forDocument: note.collection("images").document(id))
    }
    for id in oldIDs where !ids.contains(id) { batch.deleteDocument(note.collection("images").document(id)) }
    batch.setData([
      "title": entry.title, "body": entry.body, "date": entry.date,
      "isDraft": entry.isDraft, "tags": entry.tagList, "photoIDs": ids,
      "updatedAt": FieldValue.serverTimestamp(), "schemaVersion": 2,
    ], forDocument: note)
    try check(epoch, account)
    try await batch.commit()
  }

  private func deleteNote(_ note: DocumentReference) async throws {
    // Firestore does not cascade parent deletion. Leave the parent until all children are gone.
    while true {
      try Task.checkCancellation()
      let children = try await note.collection("images").limit(to: 20).getDocuments(source: .server)
      let batch = database.batch()
      for child in children.documents { batch.deleteDocument(child.reference) }
      if children.documents.count < 20 { batch.deleteDocument(note) }
      try await batch.commit()
      if children.documents.count < 20 { return }
    }
  }

  private func restorePhotos(_ ids: [String], note: DocumentReference, staging: URL, epoch: UUID, account: String) async throws -> [String] {
    try NotePhotoPayload.validateIDs(ids)
    let folder = directory.appendingPathComponent("Photos").appendingPathComponent(account)
    for id in ids {
      try check(epoch, account)
      let url = folder.appendingPathComponent(id + ".jpg")
      // Existing local originals remain untouched. Only missing files are fetched.
      if FileManager.default.fileExists(atPath: url.path) { continue }
      let snapshot = try await note.collection("images").document(id).getDocument(source: .server)
      try check(epoch, account)
      guard let data = snapshot.data() else { throw CoastStoreError("notes.missingPhoto") }
      // Ignore server timestamp while decoding the explicit image schema.
      var imageData = data; imageData.removeValue(forKey: "updatedAt")
      let payload = try JSONDecoder().decode(NotePhotoPayload.self, from: JSONSerialization.data(withJSONObject: imageData))
      let staged = staging.appendingPathComponent(id + ".jpg")
      try await Task.detached(priority: .utility) { try NotePhotoCodec.restore(payload, to: staged) }.value
      try check(epoch, account)
    }
    return ids.map { $0 + ".jpg" }
  }

  private func readAndMergeAll(_ collection: CollectionReference, epoch: UUID, account: String) async throws {
    let staging = FileManager.default.temporaryDirectory.appendingPathComponent("CoastWildNoteImages").appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: staging) }
    var result: [CoastEntry] = []
    var cursor: DocumentSnapshot?
    while true {
      try Task.checkCancellation()
      var query = collection.order(by: FieldPath.documentID()).limit(to: 200)
      if let cursor { query = query.start(afterDocument: cursor) }
      let page = try await query.getDocuments(source: .server)
      try check(epoch, account)
      for document in page.documents {
        // A pending local edit/deletion owns its image list until its upload succeeds.
        if store.pendingNoteIDs.contains(document.documentID) { continue }
        let data = document.data()
        guard let title = data["title"] as? String, title.count <= 80,
              let body = data["body"] as? String, body.count <= 10_000,
              let date = data["date"] as? String, CoastValidation.parseDate(date) != nil,
              let draft = data["isDraft"] as? Bool, let tags = data["tags"] as? [String],
              CoastValidation.tags(tags) == nil else { throw CoastStoreError("notes.invalidRemote") }
        var entry = CoastEntry(id: document.documentID, title: title, body: body, date: date,
                               isDraft: draft, tags: tags)
        if data["schemaVersion"] as? Int == 2 {
          guard let ids = data["photoIDs"] as? [String] else { throw CoastStoreError("notes.invalidPhoto") }
          entry.cloudPhotoIDs = ids
          entry.photos = try await restorePhotos(ids, note: document.reference, staging: staging, epoch: epoch, account: account)
        }
        result.append(entry)
      }
      guard page.documents.count == 200 else {
        try check(epoch, account)
        // No suspension between promotion and the ledger merge: cleanup cannot
        // remove downloaded files while their note references are still being fetched.
        try NotePhotoCodec.installRestoredFiles(result.flatMap(\.photos), from: staging,
          to: directory.appendingPathComponent("Photos").appendingPathComponent(account))
        try store.mergeRemoteNotes(result)
        return
      }
      cursor = page.documents.last
    }
  }

  func deleteCurrentAccountNotes() async throws {
    guard let account = store.accountID else { return }
    // If cloud deletion only partly succeeds, a failed operation must not erase local notes on retry.
    try store.requeueAllNotes()
    paused = true; generation = UUID(); retry?.cancel()
    let outstanding = task
    outstanding?.cancel()
    // Await an already submitted write before deleting so it cannot recreate a deleted note.
    await outstanding?.value
    task = nil
    let uid = try await identity()
    let notes = collection(uid: uid, account: account)
    while true {
      let page = try await notes.limit(to: 200).getDocuments(source: .server)
      if page.isEmpty { break }
      for document in page.documents { try await deleteNote(document.reference) }
    }
  }

  func resume() { paused = false; schedule() }
  private func setStatus(_ value: String) {
    status = value
    NotificationCenter.default.post(name: Self.changed, object: nil)
  }
}

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  var coast: CoastEnvironment?
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if !CoastTestMode.isEnabled || ProcessInfo.processInfo.arguments.contains("--ui-testing-public-content") {
      FirebaseApp.configure()
      // Configure once before either public content or private notes use Firestore.
      let db = Firestore.firestore()
      let settings = db.settings
      settings.cacheSettings = MemoryCacheSettings()
      db.settings = settings
    }
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
        "Unable to open local data. Please restart.\n\(error.localizedDescription)"
      label.frame = CGRect(x: 30, y: 150, width: window.bounds.width - 60, height: 240)
      vc.view.addSubview(label)
      window.rootViewController = vc
    }
    window.makeKeyAndVisible()
    return true
  }
  func applicationDidBecomeActive(_ application: UIApplication) {
    Task {
      coast?.scheduleNoteSync()
      coast?.refreshPublicContent()
    }
  }
}
final class CoastEnvironment {
  @MainActor private lazy var noteSync = FirebaseNoteSync(store: store, deviceID: deviceID, directory: directory)
  @MainActor var noteSyncStatus: String { noteSync.status }
  @MainActor func scheduleNoteSync() {
    guard !CoastTestMode.isEnabled, privacyConsent.isAccepted,
          accountState?.deletion == nil, store.accountID != nil else { return }
    noteSync.schedule()
  }
  @MainActor func refreshPublicContent(force: Bool = false) {
    guard accountState?.deletion == nil, store.accountID != nil else { return }
    let args = ProcessInfo.processInfo.arguments
    #if DEBUG
    if CoastTestMode.isEnabled, args.contains("--ui-testing-content-retry"), privacyConsent.isAccepted {
      publicContent.refreshEmptyFixture(force: force) { [weak self] catalog in
        self?.catalog = catalog
        self?.learning.replaceLessons(catalog.lessons)
      }
      return
    }
    #endif
    guard (!CoastTestMode.isEnabled || args.contains("--ui-testing-public-content")), privacyConsent.isAccepted else { return }
    publicContent.refresh(force: force, identity: { [weak self] in
      guard let self else { throw CancellationError() }
      return try await self.noteSync.identity()
    }, apply: { [weak self] catalog in
      self?.catalog = catalog
      self?.learning.replaceLessons(catalog.lessons)
    })
  }
  let deviceIdentity: DeviceIdentityStore
  let deviceID: String
  let defaults: UserDefaults
  private let identityStorage = SecurityKeychainValueStore(service: "com.coastwild.firebase.account")
  private(set) var accountState: FirebaseAccountState?
  @MainActor private var authenticationTask: Task<Void, Error>?
  @MainActor private var deletingAccount = false
  let privacyConsent: PrivacyConsentStore
  let store: CoastStore
  private(set) var catalog: Catalog
  let publicContent: PublicContentService
  let learning: LearningRepository
  let directory: URL
  let reminders = CoastReminders()
  private var rescheduleTask: Task<Void, Never>?
  weak var window: UIWindow?
  var chinese: Bool { false }
  init() throws {
    let testing = CoastTestMode.isEnabled
    defaults = testing
      ? UserDefaults(suiteName: "com.coastwild.integration.ui-tests")!
      : UserDefaults.standard
    if testing && ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
      defaults.removePersistentDomain(forName: "com.coastwild.integration.ui-tests")
    }
    deviceIdentity = DeviceIdentityStore(
      bundleIdentifier: Bundle.main.bundleIdentifier ?? "com.huankecontact.coastwild",
      defaults: defaults
    )
    deviceID = testing ? "ui-test-device" : try deviceIdentity.resolve()
    if !testing, let value = try identityStorage.read(account: "state"), !value.isEmpty {
      accountState = try JSONDecoder().decode(FirebaseAccountState.self, from: Data(value.utf8))
    }
    privacyConsent = PrivacyConsentStore(
      defaults: defaults,
      key: "com.coastwild.integration.privacy-consent",
      currentVersion: 4
    )
    directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(testing ? "CoastWildTests" : "CoastWild")
    if testing && ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
      if FileManager.default.fileExists(atPath: directory.path) {
        try FileManager.default.removeItem(at: directory)
      }
      privacyConsent.reset()
    }
    if testing && ProcessInfo.processInfo.arguments.contains("--accept-privacy") {
      privacyConsent.accept()
    }
    let existed = FileManager.default.fileExists(atPath: directory.path)
    store = try CoastStore(directory: directory)
    if !existed {
      var prefs = store.preferences
      prefs.language = "en"
      try store.updatePreferences(prefs)
    }
    publicContent = PublicContentService(directory: directory,
      enabled: !testing || ProcessInfo.processInfo.arguments.contains("--ui-testing-public-content"))
    catalog = try publicContent.current.map(PublicContentService.catalog)
      ?? .empty
    let showLearningLoading = ProcessInfo.processInfo.arguments.contains("--show-learning-loading")
    let learningDelay: ClosedRange<UInt64> = testing
      ? (showLearningLoading ? 3_000_000_000...3_000_000_000 : 0...0)
      : 0...0
    let forcedFailure = ProcessInfo.processInfo.arguments.contains("--fail-learning-request")
    learning = LearningRepository(
      lessons: catalog.lessons,
      delayNanoseconds: learningDelay,
      shouldFail: { forcedFailure })
    try store.activate(accountID: nil)
    // 提醒排的是当前账本里的出游。出游、装备、语言或登录状态一变就整体重排，
    // 这样删掉的出游不会再弹提醒，装备数量和文案语言也不会过期。
    store.onChange = { [weak self] in
      self?.scheduleReminders()
      Task { @MainActor [weak self] in self?.scheduleNoteSync() }
    }
    scheduleReminders()
  }

  /// 合并短时间内的连续变更（例如连着勾选多件装备）后再重排。
  /// 登出后账本为空、计划回到默认关闭，这里会顺带清掉已排程的通知。
  func scheduleReminders() {
    let ledger = store.ledger
    let chinese = self.chinese
    rescheduleTask?.cancel()
    rescheduleTask = Task { [reminders] in
      try? await Task.sleep(nanoseconds: 400_000_000)
      guard !Task.isCancelled else { return }
      await reminders.reschedule(plan: ledger.reminderPlan, ledger: ledger, chinese: chinese)
    }
  }
  func t(_ en: String, _ zh: String) -> String { chinese ? zh : en }
  func text(_ value: [String: String]) -> String {
    value[chinese ? "zh-Hans" : "en"] ?? value["en"] ?? ""
  }
  func item(_ id: String) -> CoastContent? { catalog.items.first { $0.key == id } }
  func gearTemplate(_ key: String) -> CoastGearTemplate? {
    catalog.templates.first { $0.key == key }
  }
  /// 把模板展开成可写入账本的装备项；title 按当前语言固化，sourceKey 保证去重与语言无关。
  func gearItems(from template: CoastGearTemplate) -> [CoastGearItem] {
    template.items.map {
      CoastGearItem(sourceKey: $0.key, title: text($0.title), category: $0.category)
    }
  }
  func gearGroupName(_ key: String) -> String {
    key == "general" ? t("General", "通用") : category(key)
  }
  /// catalog.json 里声明的类别 key，按出现顺序。未选择兴趣时默认全选。
  var categoryKeys: [String] { (catalog.categories ?? []).map(\.key) }
  /// 卡片副标题里的类别简称，例如 Surf。
  func category(_ key: String) -> String {
    catalog.categories?.first { $0.key == key }.map { text($0.label) } ?? key
  }
  /// 筛选与分类按钮上的完整类别名，例如 Surfing。
  func categoryName(_ key: String) -> String {
    catalog.categories?.first { $0.key == key }.map { text($0.name) } ?? category(key)
  }
  /// 首页推荐位展示用的标题、副标题与配图。catalog.json 里填了覆盖值就用覆盖值，
  /// 否则回落到所指向条目自身的内容。
  func feature(_ value: CoastFeature)
    -> (item: CoastContent, title: String, subtitle: String, image: String)?
  {
    guard let item = item(value.item) else { return nil }
    return (
      item,
      value.title.map(text) ?? text(item.title),
      value.subtitle.map(text) ?? text(item.subtitle),
      value.photo.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        ?? item.image
    )
  }
  @MainActor func showRoot() {
    refreshPublicContent()
    IQKeyboardToolbarManager.shared.toolbarConfiguration.doneBarButtonConfiguration =
      IQBarButtonItemConfiguration(title: t("Done", "完成"))
    if privacyConsent.isAccepted {
      if defaults.bool(forKey: "firebase.showWelcome") || accountState?.deletion != nil {
        window?.rootViewController = navigation(RemoteLoginController(self))
      } else {
        window?.rootViewController = StartupController(self)
      }
    } else {
      window?.rootViewController = PrivacyConsentController(self)
    }
  }
  @MainActor func acceptPrivacy() {
    privacyConsent.accept()
    showRoot()
  }
  @MainActor func showMainInterface() {
    refreshPublicContent()
    let tabs = CoastTabBarController()
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
  private func persistAccount(_ state: FirebaseAccountState?) throws {
    if !CoastTestMode.isEnabled {
      let value = try state.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) } ?? ""
      try identityStorage.write(value, account: "state", accessibility: .afterFirstUnlockThisDeviceOnly)
    }
    accountState = state
  }

  @MainActor func firebaseLogin() async throws {
    guard privacyConsent.isAccepted, !deletingAccount, accountState?.deletion == nil else {
      throw NSError(domain: "CoastWild.Auth", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Account deletion is pending. Please retry deletion."])
    }
    if let authenticationTask { return try await authenticationTask.value }
    let task = Task { @MainActor in try await self.activateFirebaseAccount() }
    authenticationTask = task
    defer { authenticationTask = nil }
    try await task.value
  }

  @MainActor private func activateFirebaseAccount() async throws {
    let testing = CoastTestMode.isEnabled
    let uid: String
    var legacy: String?
    if testing {
      uid = "firebase-ui-test-user"
    } else {
      let existing = Auth.auth().currentUser
      // The alias is valid only when the original Firebase identity is still retained.
      if existing != nil, accountState == nil,
         let data = defaults.data(forKey: "LanlinLoginData"),
         let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        legacy = value["userID"] as? String
      }
      if let state = accountState, existing?.uid != state.uid {
        throw NSError(domain: "CoastWild.Auth", code: 3,
          userInfo: [NSLocalizedDescriptionKey: "The saved account identity is unavailable. Your local data has been preserved. Contact support before resetting it."])
      }
      if let existing { uid = existing.uid }
      else { uid = try await Auth.auth().signInAnonymously().user.uid }
    }
    let state = accountState ?? FirebaseAccountState(uid: uid, legacyAccount: legacy)
    guard state.belongs(to: uid) else { throw CancellationError() }
    try persistAccount(state)
    defaults.removeObject(forKey: "LanlinLoginData")
    defaults.removeObject(forKey: "logindKey")
    try store.activate(accountID: state.account)
    var prefs = store.preferences
    prefs.onboardingDone = true
    try store.updatePreferences(prefs)
    defaults.set(false, forKey: "firebase.showWelcome")
    if !testing { noteSync.resume() }
    showMainInterface()
  }

  @MainActor func logout() async throws {
    // Preserve the anonymous credential: Firebase signOut would orphan this account.
    guard !deletingAccount else { return }
    defaults.set(true, forKey: "firebase.showWelcome")
    try store.activate(accountID: nil)
    window?.rootViewController = navigation(RemoteLoginController(self))
  }
  @MainActor func deleteAccount() async throws {
    guard !deletingAccount, authenticationTask == nil else { throw AccountDeletionError.alreadyInProgress }
    guard let state = accountState else { return }
    deletingAccount = true
    defer { deletingAccount = false }
    let testing = CoastTestMode.isEnabled
    try store.activate(accountID: state.account)
    try await FirebaseDeletionWorkflow.run(state: state, save: { value in
      try self.persistAccount(value)
    }, cloud: {
      #if DEBUG
      if testing && ProcessInfo.processInfo.arguments.contains("--account-deletion-fails") {
        throw URLError(.notConnectedToInternet)
      }
      #endif
      if !testing {
        guard Auth.auth().currentUser?.uid == state.uid else { throw CancellationError() }
        try await self.noteSync.deleteCurrentAccountNotes()
      }
    }, identity: {
      if !testing, let user = Auth.auth().currentUser {
        guard user.uid == state.uid else { throw CancellationError() }
        try await user.delete()
      }
    }, local: {
      let photos = self.directory.appendingPathComponent("Photos").appendingPathComponent(state.account)
      if FileManager.default.fileExists(atPath: photos.path) { try FileManager.default.removeItem(at: photos) }
      try self.store.deleteCurrentAccountData()
      self.defaults.set(true, forKey: "firebase.showWelcome")
    })
    window?.rootViewController = navigation(RemoteLoginController(self))
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
      "entry.tags.tooMany": ("You can add up to 5 tags.", "最多可以添加 5 个标签。"),
      "entry.tag.required": ("Enter a tag.", "请输入标签内容。"),
      "entry.tag.tooLong": ("Tags can have up to 12 characters.", "单个标签最多 12 个字符。"),
      "entry.tag.duplicate": ("That tag is already on this entry.", "这篇手记已经有这个标签。"),
      "checklist.title.required": ("Enter an item name.", "请输入物品名称。"),
      "checklist.title.tooLong": (
        "Item names can have up to 40 characters.", "物品名称最多 40 个字符。"
      ),
      "checklist.category.invalid": ("Choose a checklist group.", "请选择清单分组。"),
      "checklist.duplicate": ("This item is already in that group.", "该分组已有同名物品。"),
      "checklist.tooMany": ("A checklist can hold up to 60 items.", "单份清单最多 60 项。"),
      "checklist.notFound": ("That item is no longer on the list.", "该物品已不在清单中。"),
      "checklist.id.required": ("Could not add that item. Try again.", "未能添加该物品，请重试。"),
      "checklist.id.duplicate": ("Could not add that item. Try again.", "未能添加该物品，请重试。"),
      "checklist.order.invalid": ("Could not add that item. Try again.", "未能添加该物品，请重试。"),
      "reminder.lead.invalid": (
        "Choose between 0 and 7 days before departure.", "请选择出发前 0 至 7 天。"
      ),
      "reminder.time.invalid": ("Enter a time as HH:mm.", "请输入 HH:mm 格式的时刻。"),
    ]
    if let value = validation[key] { return t(value.0, value.1) }
    return t(
      "Could not save. Check your input and try again. Your edits are retained.",
      "未能保存，请检查输入后重试。你的编辑内容已保留。")
  }
}

/// Keep root page titles in the content, as specified by HF-v1.2.
final class CoastTabBarController: UITabBarController, UITabBarControllerDelegate {
  private weak var preparedView: UIView?

  override func viewDidLoad() {
    super.viewDidLoad()
    delegate = self
  }

  func tabBarController(
    _ tabBarController: UITabBarController, shouldSelect viewController: UIViewController
  ) -> Bool {
    guard viewController !== selectedViewController else { return true }
    preparedView?.layer.removeAllAnimations()
    preparedView?.alpha = 1
    preparedView?.transform = .identity
    preparedView = nil
    guard !UIAccessibility.isReduceMotionEnabled, view.window != nil else { return true }
    let target = viewController.view!
    target.layer.removeAllAnimations()
    target.alpha = 0
    target.transform = CGAffineTransform(translationX: 0, y: CoastMotion.tabOffset)
    preparedView = target
    return true
  }

  func tabBarController(
    _ tabBarController: UITabBarController, didSelect viewController: UIViewController
  ) {
    guard let target = preparedView, target === viewController.view else { return }
    UIView.animate(
      withDuration: CoastMotion.tabDuration, delay: 0,
      options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
    ) {
      target.alpha = 1
      target.transform = .identity
    } completion: { [weak self, weak target] _ in
      target?.alpha = 1
      target?.transform = .identity
      if self?.preparedView === target { self?.preparedView = nil }
    }
  }
}

final class CoastNavigationController: UINavigationController,
  UINavigationControllerDelegate, UIGestureRecognizerDelegate
{
  private var interactiveTransition: UIPercentDrivenInteractiveTransition?
  private lazy var edgePanGesture = UIPanGestureRecognizer(
    target: self, action: #selector(handleEdgePan(_:)))
  var coastInteractivePopGestureRecognizer: UIGestureRecognizer { edgePanGesture }

  override func viewDidLoad() {
    super.viewDidLoad()
    delegate = self
    interactivePopGestureRecognizer?.isEnabled = false
    edgePanGesture.delegate = self
    (interactivePopGestureRecognizer?.view ?? view).addGestureRecognizer(edgePanGesture)
  }

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer, viewControllers.count > 1 else {
      return false
    }
    let velocity = pan.velocity(in: view)
    let startX = pan.location(in: view).x - pan.translation(in: view).x
    return startX <= 32 && velocity.x > abs(velocity.y)
  }

  @objc private func handleEdgePan(_ gesture: UIPanGestureRecognizer) {
    let width = max(view.bounds.width, 1)
    let progress = min(max(gesture.translation(in: view).x / width, 0), 1)

    if UIAccessibility.isReduceMotionEnabled {
      guard gesture.state == .ended else { return }
      let shouldPop = progress > 0.35 || gesture.velocity(in: view).x > 450
      if shouldPop { _ = popViewController(animated: false) }
      return
    }

    switch gesture.state {
    case .began:
      guard viewControllers.count > 1 else { return }
      let transition = UIPercentDrivenInteractiveTransition()
      transition.completionCurve = .easeOut
      interactiveTransition = transition
      _ = popViewController(animated: true)
    case .changed:
      interactiveTransition?.update(progress)
    case .ended:
      if progress > 0.35 || gesture.velocity(in: view).x > 450 {
        interactiveTransition?.finish()
      } else {
        interactiveTransition?.cancel()
      }
      interactiveTransition = nil
    case .cancelled, .failed:
      interactiveTransition?.cancel()
      interactiveTransition = nil
    default:
      break
    }
  }

  override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    for controller in viewControllers + [viewController] {
      controller.navigationItem.backButtonDisplayMode = .minimal
    }
    super.pushViewController(
      viewController, animated: animated && !UIAccessibility.isReduceMotionEnabled)
  }

  override func popViewController(animated: Bool) -> UIViewController? {
    super.popViewController(animated: animated && !UIAccessibility.isReduceMotionEnabled)
  }

  override func popToRootViewController(animated: Bool) -> [UIViewController]? {
    super.popToRootViewController(animated: animated && !UIAccessibility.isReduceMotionEnabled)
  }

  override func popToViewController(
    _ viewController: UIViewController, animated: Bool
  ) -> [UIViewController]? {
    super.popToViewController(
      viewController, animated: animated && !UIAccessibility.isReduceMotionEnabled)
  }

  override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
    for controller in viewControllers {
      controller.navigationItem.backButtonDisplayMode = .minimal
    }
    super.setViewControllers(
      viewControllers, animated: animated && !UIAccessibility.isReduceMotionEnabled)
  }

  func navigationController(
    _ navigationController: UINavigationController, willShow viewController: UIViewController,
    animated: Bool
  ) {
    let root =
      viewController is ExploreController || viewController is LearnController
      || viewController is TripsController || viewController is JournalController
    setNavigationBarHidden(
      root, animated: animated && !UIAccessibility.isReduceMotionEnabled)
  }

  func navigationController(
    _ navigationController: UINavigationController,
    animationControllerFor operation: UINavigationController.Operation,
    from fromVC: UIViewController, to toVC: UIViewController
  ) -> UIViewControllerAnimatedTransitioning? {
    guard !UIAccessibility.isReduceMotionEnabled else { return nil }
    return CoastNavigationAnimator(operation: operation)
  }

  func navigationController(
    _ navigationController: UINavigationController,
    interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
  ) -> UIViewControllerInteractiveTransitioning? {
    interactiveTransition
  }
}

final class CoastNavigationAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  private let operation: UINavigationController.Operation
  private var runningAnimator: UIViewPropertyAnimator?

  init(operation: UINavigationController.Operation) {
    self.operation = operation
    super.init()
  }

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?)
    -> TimeInterval
  {
    operation == .pop ? CoastMotion.popDuration : CoastMotion.pushDuration
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    interruptibleAnimator(using: transitionContext).startAnimation()
  }

  func interruptibleAnimator(
    using transitionContext: UIViewControllerContextTransitioning
  ) -> UIViewImplicitlyAnimating {
    if let runningAnimator { return runningAnimator }
    guard
      let from = transitionContext.view(forKey: .from),
      let to = transitionContext.view(forKey: .to)
    else {
      let fallback = UIViewPropertyAnimator(duration: 0, curve: .linear) {
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
      }
      runningAnimator = fallback
      return fallback
    }

    let container = transitionContext.containerView
    let distance = max(container.bounds.width, 1)
    let pushing = operation != .pop
    to.frame = transitionContext.finalFrame(
      for: transitionContext.viewController(forKey: .to)!)
    if pushing {
      container.addSubview(to)
      to.transform = CGAffineTransform(translationX: distance, y: 0)
    } else {
      container.insertSubview(to, belowSubview: from)
      to.transform = CGAffineTransform(translationX: -distance * 0.22, y: 0)
    }

    // A restrained leading-edge shadow keeps the moving page readable against
    // similarly light HF-V1 backgrounds without adding a second animation style.
    let foreground = pushing ? to : from
    foreground.layer.masksToBounds = false
    foreground.layer.shadowColor = UIColor.black.cgColor
    foreground.layer.shadowOffset = CGSize(width: -5, height: 0)
    foreground.layer.shadowRadius = 11
    foreground.layer.shadowOpacity = 0.14

    let timing = UICubicTimingParameters(
      controlPoint1: CGPoint(x: 0.25, y: 1),
      controlPoint2: CGPoint(x: 0.5, y: 1))
    let animator = UIViewPropertyAnimator(
      duration: transitionDuration(using: transitionContext), timingParameters: timing)
    animator.addAnimations {
      if pushing {
        from.transform = CGAffineTransform(translationX: -distance * 0.22, y: 0)
        to.transform = .identity
      } else {
        from.transform = CGAffineTransform(translationX: distance, y: 0)
        to.transform = .identity
      }
    }
    animator.addCompletion { [weak self] _ in
      let completed = !transitionContext.transitionWasCancelled
      from.transform = .identity
      to.transform = .identity
      foreground.layer.shadowOpacity = 0
      foreground.layer.shadowRadius = 0
      foreground.layer.shadowOffset = .zero
      if !completed { to.removeFromSuperview() }
      transitionContext.completeTransition(completed)
      self?.runningAnimator = nil
    }
    runningAnimator = animator
    return animator
  }

  func animationEnded(_ transitionCompleted: Bool) {
    runningAnimator = nil
  }
}
