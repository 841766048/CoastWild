import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class JournalController: CoastController {
  var drafts = false
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = iconItem("plus", label: env.t("New entry", "新手记")) {
      [weak self] in
      guard let self else { return }
      self.push(JournalEditorController(self.env, entry: nil))
    }
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset()
    title = env.t("Journal", "手记")
    heading(env.t("Journal", "手记"))
    note(env.t("Keep the moments that stay with you.", "把值得记住的片刻留下。"))
    chips([env.t("Entries", "手记"), env.t("Drafts", "草稿")], selected: drafts ? 1 : 0) {
      [weak self] i in
      self?.drafts = i == 1
      self?.render()
    }
    let entries = env.store.ledger.entries.filter { $0.isDraft == drafts }
    if entries.isEmpty {
      empty(
        env.t("A blank page, your memories", "空白的一页，新的回忆"),
        env.t("A few words or a photo is a good place to begin.", "用几句话或一张照片，记下户外的片刻。"),
        icon: "journal")
      add(
        coastButton(env.t("Write your first entry", "写下第一篇手记")) { [weak self] in
          guard let self else { return }
          self.push(JournalEditorController(self.env, entry: nil))
        })
    }
    entries.forEach { entry in
      if let photo = entry.photos.first, let image = env.photo(photo) {
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 16
        view.heightAnchor.constraint(equalToConstant: 220).isActive = true
        add(view)
      }
      add(
        row(
          title: entry.title.isEmpty ? env.t("Untitled entry", "未命名手记") : entry.title,
          subtitle: entry.date + " · " + String(entry.body.prefix(90))
        ) { [weak self] in
          guard let self else { return }
          if entry.isDraft {
            self.push(JournalEditorController(self.env, entry: entry))
          } else {
            self.push(JournalDetailController(self.env, id: entry.id))
          }
        })
    }
  }
}
final class JournalEditorController: CoastController, UITextViewDelegate,
  PHPickerViewControllerDelegate
{
  var entry: CoastEntry
  let original: CoastEntry?
  var titleField: UITextField!, dateField: UITextField!, bodyField: UITextView!,
    tripButton: UIButton!, status = coastLabel("", size: 13, color: CoastStyle.muted)
  var activityButton: UIButton!
  let photoStack = UIStackView()
  var pending: DispatchWorkItem?
  var finished = false
  var importing = false
  init(_ env: CoastEnvironment, entry: CoastEntry?, tripID: String? = nil) {
    self.entry = entry ?? CoastEntry()
    original = entry
    if entry == nil { self.entry.tripID = tripID }
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  deinit { pending?.cancel() }
  override func viewDidLoad() {
    super.viewDidLoad()
    title = env.t("New entry", "新手记")
    navigationItem.hidesBackButton = true
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: env.t("Cancel", "取消"), primaryAction: UIAction { [weak self] _ in self?.cancel() })
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: env.t("Save", "保存"), primaryAction: UIAction { [weak self] _ in self?.submit() })
    titleField = field(
      env.t("Title", "标题"), placeholder: env.t("Give your memory a name", "给回忆起个名字"),
      value: entry.title, id: "journal.title")
    dateField = field(env.t("Date", "日期"), value: entry.date)
    dateField.keyboardType = .numbersAndPunctuation
    add(
      coastButton(env.t("Add photos", "添加照片"), secondary: true) { [weak self] in self?.pickPhotos()
      })
    photoStack.axis = .vertical
    photoStack.spacing = 12
    add(photoStack)
    refreshPhotos()
    bodyField = textArea(
      env.t("What would you like to remember?", "有什么想要记住的？"), value: entry.body, height: 220)
    bodyField.accessibilityIdentifier = "journal.body"
    bodyField.delegate = self
    tripButton = coastButton(tripTitle(), secondary: true) { [weak self] in self?.chooseTrip() }
    add(tripButton)
    activityButton = coastButton(activityTitle(), secondary: true) { [weak self] in
      self?.chooseActivity()
    }
    add(activityButton)
    add(status)
    status.text = env.t("Your draft saves as you write.", "书写时自动保存草稿。")
    [titleField, dateField].forEach {
      $0?.addAction(UIAction { [weak self] _ in self?.scheduleDraft() }, for: .editingChanged)
    }
  }
  func tripTitle() -> String {
    guard let trip = env.store.ledger.trips.first(where: { $0.id == entry.tripID }) else {
      return env.t("No linked trip", "不关联出游")
    }
    return trip.name
  }
  func chooseTrip() {
    menu(
      env.t("Link a trip", "关联出游"),
      choices: [
        (
          env.t("None", "不关联出游"),
          { [weak self] in
            self?.entry.tripID = nil
            self?.updateTrip()
          }
        )
      ]
        + env.store.ledger.trips.map { trip in
          (
            trip.name,
            { [weak self] in
              self?.entry.tripID = trip.id
              self?.updateTrip()
            }
          )
        })
  }
  func activityTitle() -> String {
    guard let id = entry.activityID, let item = env.item(id) else {
      return env.t("No linked experience", "不关联体验")
    }
    return env.text(item.title)
  }
  func chooseActivity() {
    menu(
      env.t("Link experience", "关联体验"),
      choices: [
        (
          env.t("None", "不关联体验"),
          { [weak self] in
            self?.entry.activityID = nil
            self?.updateActivity()
          }
        )
      ]
        + env.catalog.items.map { item in
          (
            env.text(item.title),
            { [weak self] in
              self?.entry.activityID = item.key
              self?.updateActivity()
            }
          )
        })
  }
  func updateActivity() {
    activityButton.configuration?.title = activityTitle()
    scheduleDraft()
  }
  func updateTrip() {
    tripButton.configuration?.title = tripTitle()
    scheduleDraft()
  }
  func textViewDidChange(_ textView: UITextView) { scheduleDraft() }
  func capture() {
    entry.title = titleField.text ?? ""
    entry.body = bodyField.text ?? ""
    entry.date = dateField.text ?? ""
  }
  func scheduleDraft() {
    guard !finished else { return }
    pending?.cancel()
    status.text = env.t("Saving draft…", "正在保存草稿…")
    let work = DispatchWorkItem { [weak self] in self?.persistDraft() }
    pending = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
  }
  @discardableResult func persistDraft() -> Bool {
    guard !finished else { return false }
    capture()
    guard !entry.title.isEmpty || !entry.body.isEmpty || !entry.photos.isEmpty else { return true }
    var draft = entry
    draft.isDraft = true
    do {
      try env.store.saveEntry(draft)
      status.text = env.t("Draft saved", "草稿已保存")
      return true
    } catch {
      status.text = env.t(
        "Draft not saved. Your edits are still here; tap Save to retry.", "草稿未保存。编辑内容仍保留，可点击保存重试。")
      status.textColor = CoastStyle.red
      return false
    }
  }
  func submit() {
    guard !importing else { return }
    pending?.cancel()
    capture()
    entry.isDraft = false
    if let issue = CoastValidation.entry(entry) {
      status.text =
        env.t(
          "Add text or a photo; title up to 80, body up to 10,000 characters.",
          "请填写正文或添加照片；标题最多 80 字，正文最多 10000 字。") + "\n" + env.errorText(CoastStoreError(issue))
      status.textColor = CoastStyle.red
      return
    }
    if save({ try env.store.saveEntry(entry) }) {
      finished = true
      navigationController?.popViewController(animated: true)
    }
  }
  func cancel() {
    guard !importing else { return }
    pending?.cancel()
    capture()
    if original == nil && entry.title.isEmpty && entry.body.isEmpty && entry.photos.isEmpty {
      finished = true
      navigationController?.popViewController(animated: true)
      return
    }
    menu(
      env.t("Keep your draft?", "保留草稿吗？"),
      choices: [
        (
          env.t("Keep draft", "保留草稿"),
          { [weak self] in
            guard let self else { return }
            if self.persistDraft() {
              self.finished = true
              self.navigationController?.popViewController(animated: true)
            }
          }
        ),
        (
          env.t("Discard changes", "丢弃本次修改"),
          { [weak self] in
            guard let self else { return }
            if self.save({
              if let original = self.original {
                try self.env.store.saveEntry(original)
              } else {
                try self.env.store.deleteEntry(id: self.entry.id)
              }
            }) {
              self.finished = true
              self.navigationController?.popViewController(animated: true)
            }
          }
        ),
      ])
  }
  func pickPhotos() {
    guard entry.photos.count < 12 else {
      message(
        env.t("Photo limit", "照片数量上限"), env.t("You can add up to 12 photos.", "最多可以添加 12 张照片。"))
      return
    }
    var config = PHPickerConfiguration(photoLibrary: .shared())
    config.filter = .images
    config.selectionLimit = 12 - entry.photos.count
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    present(picker, animated: true)
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard !results.isEmpty else { return }
    importing = true
    navigationItem.rightBarButtonItem?.isEnabled = false
    status.text = env.t("Importing photos…", "正在导入照片…")
    let group = DispatchGroup()
    var imported: [String] = []
    var failed = false
    for result in results {
      group.enter()
      result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
        guard let self else {
          group.leave()
          return
        }
        guard let image = object as? UIImage, let bytes = image.jpegData(compressionQuality: 0.85)
        else {
          DispatchQueue.main.async {
            failed = true
            group.leave()
          }
          return
        }
        let filename = UUID().uuidString + ".jpg"
        do {
          let url = self.env.photoURL(filename)
          try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
          try bytes.write(to: url, options: [.atomic, .completeFileProtection])
          DispatchQueue.main.async {
            imported.append(filename)
            group.leave()
          }
        } catch {
          DispatchQueue.main.async {
            failed = true
            group.leave()
          }
        }
      }
    }
    group.notify(queue: .main) { [weak self] in
      guard let self else { return }
      self.entry.photos.append(contentsOf: imported)
      self.importing = false
      self.navigationItem.rightBarButtonItem?.isEnabled = true
      self.refreshPhotos()
      self.scheduleDraft()
      if failed {
        self.message(
          self.env.t("Some photos could not be imported", "部分照片未能导入"),
          self.env.t(
            "Your text and existing photos are retained. Try another photo.", "文字和已有照片均保留，请尝试其他照片。")
        )
      }
    }
  }
  func refreshPhotos() {
    photoStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    for filename in entry.photos {
      if let image = env.photo(filename) {
        let iv = UIImageView(image: image)
        iv.heightAnchor.constraint(equalToConstant: 160).isActive = true
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        photoStack.addArrangedSubview(iv)
        photoStack.addArrangedSubview(
          coastButton(env.t("Remove photo", "移除照片"), secondary: true) { [weak self] in
            self?.entry.photos.removeAll { $0 == filename }
            self?.refreshPhotos()
            self?.scheduleDraft()
          })
      }
    }
  }
}
final class JournalDetailController: CoastController {
  let id: String
  init(_ env: CoastEnvironment, id: String) {
    self.id = id
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset()
    guard let entry = env.store.ledger.entries.first(where: { $0.id == id }) else {
      navigationController?.popViewController(animated: true)
      return
    }
    title = env.t("Journal", "手记")
    navigationItem.rightBarButtonItems = [
      iconItem("more", label: env.t("More", "更多")) { [weak self] in self?.more(entry) },
      iconItem("share", label: env.t("Share", "分享")) { [weak self] in self?.share(entry) },
    ]
    note(entry.date)
    heading(entry.title)
    add(coastLabel(entry.body))
    for filename in entry.photos {
      if let image = env.photo(filename) {
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 16
        iv.heightAnchor.constraint(equalToConstant: 280).isActive = true
        add(iv)
      }
    }
    if let trip = env.store.ledger.trips.first(where: { $0.id == entry.tripID }) {
      add(
        coastButton(trip.name, secondary: true) { [weak self] in
          guard let self else { return }
          self.push(TripDetailController(self.env, id: trip.id))
        })
    }
  }
  func more(_ entry: CoastEntry) {
    menu(
      env.t("Entry options", "手记选项"),
      choices: [
        (
          env.t("Edit", "编辑"),
          { [weak self] in
            guard let self else { return }
            self.push(JournalEditorController(self.env, entry: entry))
          }
        ),
        (
          env.t("Delete", "删除"),
          { [weak self] in
            guard let self else { return }
            self.confirm(
              self.env.t("Delete this entry?", "删除这篇手记？"),
              self.env.t(
                "Only app-owned copies are removed. Your photo library is unchanged.",
                "只删除应用中的附件副本，不影响系统照片库原图。")
            ) {
              if self.save({ try self.env.store.deleteEntry(id: entry.id) }) {
                for filename in entry.photos {
                  try? FileManager.default.removeItem(at: self.env.photoURL(filename))
                }
                self.navigationController?.popViewController(animated: true)
              }
            }
          }
        ),
      ])
  }
  func share(_ entry: CoastEntry) {
    var items: [Any] = [entry.title + "\n" + entry.body]
    items.append(contentsOf: entry.photos.compactMap { env.photo($0) })
    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    vc.popoverPresentationController?.sourceView = view
    present(vc, animated: true)
  }
}
