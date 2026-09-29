import PhotosUI
import UIKit
import UniformTypeIdentifiers

final class JournalController: CoastController {
  var drafts = false
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset()
    title = nil; contentTop.constant = 18; stack.spacing = 12
    add(
      journalRootHeader(
        env.t("Journal", "手记"), label: env.t("New entry", "新手记"),
        calendarLabel: env.t("Calendar", "日历"),
        calendar: { [weak self] in
          guard let self else { return }; self.push(JournalCalendarController(self.env))
        }
      ) { [weak self] in
        guard let self else { return }; self.push(JournalEditorController(self.env, entry: nil))
      })
    add(coastLabel(env.t("Keep the moments that stay with you.", "把舍不得忘记的片刻留下。"), size: 16, color: CoastStyle.muted))
    let draftCount = env.store.ledger.entries.filter(\.isDraft).count
    chips([env.t("Entries", "手记"), env.t("Drafts", "草稿") + " · \(draftCount)"], selected: drafts ? 1 : 0) {
      [weak self] i in
      self?.drafts = i == 1
      self?.render()
    }
    let entries = env.store.ledger.entries.filter { $0.isDraft == drafts }
    if entries.isEmpty {
      empty(env.t("A blank page, your memories", "空白的一页，新的回忆"),
        env.t("A few words or a photo is a good place to begin.", "用几句话或一张照片，记下户外的片刻。"),
        icon: "journal", actionTitle: env.t("Write your first entry", "写下第一篇手记")) { [weak self] in
          guard let self else { return }; self.push(JournalEditorController(self.env, entry: nil))
        }
    }
    entries.forEach { entry in
      let linkedTrip = env.store.ledger.trips.first(where: { $0.id == entry.tripID })?.name
      add(journalCard(entry: entry, image: entry.photos.first.flatMap { env.photo($0) }, linkedTrip: linkedTrip,
        untitled: env.t("Untitled entry", "未命名手记")) { [weak self] in
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
  let tagStack = UIStackView()
  let original: CoastEntry?
  var dateField: CoastDateField!
  var titleField: UITextField!, bodyField: UITextView!,
    tripButton: UIButton!, status = coastLabel("", size: 13, color: CoastStyle.muted)
  var bodyPlaceholder: UILabel!
  var activityButton: UIButton!
  let photoStack = UIStackView()
  var pending: DispatchWorkItem?
  var finished = false
  var hasChanges = false
  var importing = false
  init(_ env: CoastEnvironment, entry: CoastEntry?, tripID: String? = nil) {
    original = entry
    if let entry, !entry.isDraft {
      if let draft = env.store.ledger.entries.first(where: {
        $0.isDraft && $0.sourceEntryID == entry.id
      }) {
        self.entry = draft
      } else {
        var draft = entry
        draft.id = UUID().uuidString
        draft.sourceEntryID = entry.id
        draft.isDraft = true
        self.entry = draft
      }
    } else {
      self.entry = entry ?? CoastEntry()
    }
    if entry == nil { self.entry.tripID = tripID }
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  deinit { pending?.cancel() }
  override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.default.addObserver(
      self, selector: #selector(flushDraft), name: UIApplication.willResignActiveNotification,
      object: nil)
    title = env.t("New entry", "新手记")
    navigationItem.hidesBackButton = true
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: env.t("Cancel", "取消"), primaryAction: UIAction { [weak self] _ in self?.cancel() })
    let saveItem = UIBarButtonItem(
      title: env.t("Save", "保存"), primaryAction: UIAction { [weak self] _ in self?.submit() })
    saveItem.accessibilityIdentifier = "journal.save"
    navigationItem.rightBarButtonItem = saveItem
    contentTop.constant = 23; stack.spacing = 14
    titleField = UITextField(); titleField.text = entry.title
    let titlePlaceholder = env.t("Give your memory a name", "给回忆起个名字")
    titleField.attributedPlaceholder = NSAttributedString(string: titlePlaceholder,
      attributes: [.foregroundColor: UIColor(hex: 0x757575), .font: CoastStyle.font(26, .bold)])
    titleField.font = CoastStyle.font(26, .bold); titleField.textColor = CoastStyle.ink
    titleField.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
    titleField.accessibilityIdentifier = "journal.title"; add(titleField)
    stack.setCustomSpacing(31, after: titleField)
    dateField = CoastDateField(self, title: env.t("Date", "日期"), value: entry.date, id: "journal.date", allowsClear: false)
    dateField.accessibilityLabel = env.t("Date", "日期"); add(dateField)
    stack.setCustomSpacing(24, after: dateField)
    let addPhotos = coastButton(env.t("Add photos", "添加照片"), secondary: true) { [weak self] in self?.pickPhotos() }
    addPhotos.configuration?.image = UIImage(named: "icon-photo"); addPhotos.configuration?.imagePadding = 8; add(addPhotos)
    stack.setCustomSpacing(11, after: addPhotos)
    photoStack.axis = .vertical
    photoStack.spacing = 12
    add(photoStack)
    refreshPhotos()
    bodyField = UITextView(); bodyField.text = entry.body; bodyField.font = CoastStyle.font(16)
    bodyField.textColor = CoastStyle.ink; bodyField.backgroundColor = .clear; bodyField.textContainerInset = .zero
    bodyField.typingAttributes[.paragraphStyle] = journalParagraph(lineHeight: 26.4)
    bodyField.attributedText = NSAttributedString(string: entry.body, attributes: [.font: CoastStyle.font(16), .foregroundColor: CoastStyle.ink, .paragraphStyle: journalParagraph(lineHeight: 26.4)])
    let bodyContainer = UIView(); bodyField.translatesAutoresizingMaskIntoConstraints = false; bodyContainer.addSubview(bodyField)
    bodyPlaceholder = coastLabel(env.t("What would you like to remember?", "有什么想要记住的？"), size: 16, color: UIColor(hex: 0x757575))
    bodyPlaceholder.translatesAutoresizingMaskIntoConstraints = false; bodyContainer.addSubview(bodyPlaceholder)
    NSLayoutConstraint.activate([
      bodyContainer.heightAnchor.constraint(equalToConstant: 169), bodyField.topAnchor.constraint(equalTo: bodyContainer.topAnchor),
      bodyField.leadingAnchor.constraint(equalTo: bodyContainer.leadingAnchor), bodyField.trailingAnchor.constraint(equalTo: bodyContainer.trailingAnchor),
      bodyField.bottomAnchor.constraint(equalTo: bodyContainer.bottomAnchor), bodyPlaceholder.topAnchor.constraint(equalTo: bodyContainer.topAnchor),
      bodyPlaceholder.leadingAnchor.constraint(equalTo: bodyContainer.leadingAnchor)
    ]); bodyPlaceholder.isHidden = !entry.body.isEmpty; add(bodyContainer)
    bodyField.accessibilityIdentifier = "journal.body"
    bodyField.delegate = self
    tagStack.axis = .vertical
    tagStack.spacing = 10
    // 标签区高度随内容变化，不能用固定高度的 journalFormPanel。
    let tagPanel = coastPanel(
      [journalFieldGroup(env.t("Tags", "标签"), control: tagStack)], inset: 14)
    tagPanel.backgroundColor = UIColor(hex: 0xF3F8FA)
    tagPanel.layer.borderWidth = 0
    add(tagPanel)
    refreshTags()
    tripButton = journalSelectButton(tripTitle()) { [weak self] in self?.chooseTrip() }
    tripButton.accessibilityIdentifier = "journal.link.trip"
    add(journalFormPanel([journalFieldGroup(env.t("Link a trip", "关联出游"), control: tripButton)]))
    activityButton = journalSelectButton(activityTitle()) { [weak self] in self?.chooseActivity() }
    activityButton.accessibilityIdentifier = "journal.link.activity"
    activityButton.isHidden = entry.activityID == nil; add(activityButton)
    stack.setCustomSpacing(8, after: tripButton)
    status.font = CoastStyle.font(12)
    add(status)
    status.text = env.t("Your draft saves as you write.", "书写时自动保存草稿。")
    titleField.addAction(UIAction { [weak self] _ in self?.scheduleDraft() }, for: .editingChanged)
    dateField.addAction(UIAction { [weak self] _ in self?.scheduleDraft() }, for: .valueChanged)
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
        } + [(env.t("Link experience…", "关联体验…"), { [weak self] in self?.chooseActivity() })])
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
    activityButton.accessibilityValue = activityTitle()
    activityButton.configuration?.title = activityTitle()
    activityButton.isHidden = entry.activityID == nil
    scheduleDraft()
  }
  func updateTrip() {
    tripButton.accessibilityValue = tripTitle()
    tripButton.configuration?.title = tripTitle()
    scheduleDraft()
  }
  @objc func flushDraft() {
    pending?.cancel()
    if isViewLoaded && !finished && hasChanges { persistDraft() }
  }
  func textViewDidChange(_ textView: UITextView) { bodyPlaceholder.isHidden = !textView.text.isEmpty; scheduleDraft() }
  func capture() {
    entry.title = titleField.text ?? ""
    entry.body = bodyField.text ?? ""
    entry.date = dateField.text ?? ""
  }
  func scheduleDraft() {
    guard !finished else { return }
    hasChanges = true
    pending?.cancel()
    status.text = env.t("Saving draft…", "正在保存草稿…")
    let work = DispatchWorkItem { [weak self] in self?.persistDraft() }
    pending = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
  }
  @discardableResult func persistDraft() -> Bool {
    guard !finished else { return false }
    capture()

    var draft = entry
    draft.isDraft = true
    do {
      try env.store.saveEntry(draft)
      status.text = env.t("Draft saved", "草稿已保存")
      status.textColor = CoastStyle.muted
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
      env.cleanUnusedPhotos()
      finished = true
      navigationController?.popViewController(animated: true)
    }
  }
  func cancel() {
    guard !importing else { return }
    pending?.cancel()
    capture()
    if original == nil && entry.title.isEmpty && entry.body.isEmpty && entry.photos.isEmpty
      && entry.tagList.isEmpty
    {
      if env.store.ledger.entries.contains(where: { $0.id == entry.id }) {
        guard save({ try env.store.deleteEntry(id: entry.id) }) else { return }
      }
      env.cleanUnusedPhotos()
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
              self.env.cleanUnusedPhotos()
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
              if let original = self.original, original.isDraft {
                try self.env.store.saveEntry(original)
              } else {
                try self.env.store.deleteEntry(id: self.entry.id)
              }
            }) {
              self.env.cleanUnusedPhotos()
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
    photoStack.isHidden = photoStack.arrangedSubviews.isEmpty
  }

  /// 标签行：已有标签逐个可移除，未满 5 个时给出添加入口。
  func refreshTags() {
    tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let tags = entry.tagList
    let counter = UIStackView()
    counter.axis = .horizontal
    counter.alignment = .firstBaseline
    counter.addArrangedSubview(
      coastLabel(
        env.t(
          "Tags filter your journal and calendar.", "标签用于手记列表与日历筛选。"),
        size: 12, color: CoastStyle.muted))
    counter.addArrangedSubview(UIView())
    counter.addArrangedSubview(
      coastLabel("\(tags.count) / \(CoastEntry.tagLimit)", size: 12, color: CoastStyle.muted))
    tagStack.addArrangedSubview(counter)
    for tag in tags {
      let row = UIStackView()
      row.axis = .horizontal
      row.spacing = 8
      row.alignment = .center
      row.isLayoutMarginsRelativeArrangement = true
      row.layoutMargins = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 4)
      row.backgroundColor = CoastStyle.field
      row.layer.cornerRadius = 20
      row.addArrangedSubview(coastLabel(tag, size: 14, color: CoastStyle.brand))
      row.addArrangedSubview(UIView())
      let remove = UIButton(type: .system)
      remove.setImage(UIImage(named: "icon-close"), for: .normal)
      remove.tintColor = CoastStyle.muted
      remove.accessibilityLabel = env.t("Remove tag ", "移除标签：") + tag
      remove.widthAnchor.constraint(equalToConstant: 40).isActive = true
      remove.heightAnchor.constraint(equalToConstant: 40).isActive = true
      remove.addAction(
        UIAction { [weak self] _ in
          guard let self else { return }
          self.entry.tagList.removeAll { $0 == tag }
          self.refreshTags()
          self.scheduleDraft()
        }, for: .touchUpInside)
      row.addArrangedSubview(remove)
      row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
      tagStack.addArrangedSubview(row)
    }
    if tags.count < CoastEntry.tagLimit {
      let add = coastButton(env.t("Add a tag", "添加标签"), secondary: true) { [weak self] in
        self?.promptTag()
      }
      add.configuration?.image = UIImage(named: "icon-plus")
      add.configuration?.imagePadding = 8
      add.accessibilityIdentifier = "journal.tag.add"
      tagStack.addArrangedSubview(add)
    }
  }

  /// 标签用系统输入弹窗收集，校验交给 Core，错误文案走既有映射。
  func promptTag() {
    let alert = UIAlertController(
      title: env.t("Add a tag", "添加标签"),
      message: env.t(
        "Up to \(CoastEntry.tagLengthLimit) characters. Tags stay on this device.",
        "最多 \(CoastEntry.tagLengthLimit) 个字符。标签只保存在本机。"),
      preferredStyle: .alert)
    alert.addTextField { field in
      field.placeholder = self.env.t("For example: morning swell", "例如：晨浪")
      field.autocapitalizationType = .none
      field.accessibilityIdentifier = "journal.tag.input"
      field.returnKeyType = .done
    }
    alert.addAction(UIAlertAction(title: env.t("Cancel", "取消"), style: .cancel))
    alert.addAction(
      UIAlertAction(title: env.t("Add", "添加"), style: .default) { [weak self, weak alert] _ in
        guard let self else { return }
        let raw = alert?.textFields?.first?.text ?? ""
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let next = self.entry.tagList + [value]
        if let issue = CoastValidation.tags(next) {
          self.message(self.env.t("Tag not added", "标签未添加"), self.env.errorText(CoastStoreError(issue)))
          return
        }
        self.entry.tagList = next
        self.refreshTags()
        self.scheduleDraft()
      })
    present(alert, animated: true)
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
    navigationItem.rightBarButtonItem = iconItem("more", label: env.t("More", "更多")) { [weak self] in self?.more(entry) }
    contentTop.constant = 27; stack.spacing = 14
    if let first = entry.photos.first, let image = env.photo(first) {
      let hero = UIImageView(image: image); hero.contentMode = .scaleAspectFill; hero.clipsToBounds = true
      hero.layer.cornerRadius = 14; hero.heightAnchor.constraint(equalToConstant: 274).isActive = true; add(hero)
    }
    note(entry.date)
    add(coastLabel(entry.title, size: 32, weight: .bold))
    let body = coastLabel(entry.body, size: 16); body.attributedText = NSAttributedString(string: entry.body,
      attributes: [.font: CoastStyle.font(16), .foregroundColor: CoastStyle.ink, .paragraphStyle: journalParagraph(lineHeight: 26.4)])
    add(body)
    for filename in entry.photos.dropFirst() {
      if let image = env.photo(filename) {
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 16
        iv.heightAnchor.constraint(equalToConstant: 238).isActive = true
        add(iv)
      }
    }
    if let trip = env.store.ledger.trips.first(where: { $0.id == entry.tripID }) {
      add(coastPanel([coastSettingRow(trip.name, icon: "trips") { [weak self] in
          guard let self else { return }
          self.push(TripDetailController(self.env, id: trip.id))
        }], spacing: 0, inset: 0))
    }
    let actions = UIStackView(); actions.axis = .horizontal; actions.spacing = 10
    let edit = coastButton(env.t("Edit entry", "编辑手记"), secondary: true) { [weak self] in
      guard let self else { return }; self.push(JournalEditorController(self.env, entry: entry))
    }
    let delete = UIButton(type: .system); delete.setImage(UIImage(named: "icon-trash"), for: .normal); delete.tintColor = CoastStyle.red
    delete.layer.cornerRadius = 10; delete.layer.borderWidth = 1; delete.layer.borderColor = CoastStyle.border.cgColor
    delete.widthAnchor.constraint(equalToConstant: 50).isActive = true; delete.heightAnchor.constraint(equalToConstant: 50).isActive = true
    delete.accessibilityLabel = env.t("Delete entry", "删除手记"); delete.addAction(UIAction { [weak self] _ in self?.delete(entry) }, for: .touchUpInside)
    actions.addArrangedSubview(edit); actions.addArrangedSubview(delete); add(actions)
  }
  func more(_ entry: CoastEntry) {
    menu(
      env.t("Entry options", "手记选项"),
      choices: [
        (env.t("Share", "分享"), { [weak self] in self?.share(entry) }),
        (
          env.t("Edit", "编辑"),
          { [weak self] in
            guard let self else { return }
            self.push(JournalEditorController(self.env, entry: entry))
          }
        ),
        (
          env.t("Delete", "删除"),
          { [weak self] in self?.delete(entry) }
        ),
      ])
  }
  func delete(_ entry: CoastEntry) {
    confirm(env.t("Delete this entry?", "删除这篇手记？"),
      env.t("Only app-owned copies are removed. Your photo library is unchanged.", "只删除应用中的附件副本，不影响系统照片库原图。")) { [weak self] in
        guard let self else { return }
        if self.save({ try self.env.store.deleteEntry(id: entry.id) }) {
          self.env.cleanUnusedPhotos(); self.navigationController?.popViewController(animated: true)
        }
      }
  }
  func share(_ entry: CoastEntry) {
    var items: [Any] = [entry.title + "\n" + entry.body]
    items.append(contentsOf: entry.photos.compactMap { env.photo($0) })
    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    vc.popoverPresentationController?.sourceView = view
    present(vc, animated: true)
  }
}

private func journalRootHeader(
  _ title: String, label: String, calendarLabel: String, calendar: @escaping () -> Void,
  action: @escaping () -> Void
) -> UIView {
  let row = UIStackView(); row.axis = .horizontal; row.alignment = .center; row.spacing = 8
  row.addArrangedSubview(coastLabel(title, size: 32, weight: .bold)); row.addArrangedSubview(UIView())
  // 根页导航栏按 HF-v1.2 隐藏，日历入口只能放在内容里。
  let calendarButton = UIButton(type: .system)
  calendarButton.setImage(UIImage(named: "icon-calendar"), for: .normal)
  calendarButton.tintColor = CoastStyle.brand
  calendarButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
  calendarButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
  calendarButton.accessibilityLabel = calendarLabel
  calendarButton.accessibilityIdentifier = "journal.calendar"
  calendarButton.addAction(UIAction { _ in calendar() }, for: .touchUpInside)
  row.addArrangedSubview(calendarButton)
  let button = UIButton(type: .system); button.setImage(UIImage(systemName: "plus"), for: .normal)
  button.tintColor = CoastStyle.ink; button.backgroundColor = CoastStyle.sand; button.layer.cornerRadius = 22
  button.widthAnchor.constraint(equalToConstant: 44).isActive = true; button.heightAnchor.constraint(equalToConstant: 44).isActive = true
  button.accessibilityLabel = label; button.addAction(UIAction { _ in action() }, for: .touchUpInside); row.addArrangedSubview(button)
  return row
}
private func journalCard(entry: CoastEntry, image: UIImage?, linkedTrip: String?, untitled: String, action: @escaping () -> Void) -> UIView {
  let button = UIButton(type: .system); button.backgroundColor = .white; button.layer.borderWidth = 1
  button.layer.borderColor = CoastStyle.border.cgColor; button.layer.cornerRadius = 15; button.clipsToBounds = true
  let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 0; stack.isUserInteractionEnabled = false; stack.translatesAutoresizingMaskIntoConstraints = false
  if let image { let iv = UIImageView(image: image); iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true; iv.heightAnchor.constraint(equalToConstant: 210).isActive = true; stack.addArrangedSubview(iv) }
  let title = entry.title.isEmpty ? untitled : entry.title
  var views: [UIView] = [coastLabel(entry.date, size: 13, color: CoastStyle.muted), coastLabel(title, size: 22, weight: .bold)]
  if !entry.body.isEmpty { views.append(coastLabel(String(entry.body.prefix(110)), size: 14, color: CoastStyle.muted)) }
  if let linkedTrip { views.append(coastLabel(linkedTrip, size: 13, color: CoastStyle.muted)) }
  let copy = UIStackView(arrangedSubviews: views); copy.axis = .vertical; copy.spacing = 6; copy.isLayoutMarginsRelativeArrangement = true
  copy.layoutMargins = UIEdgeInsets(top: 13, left: 15, bottom: 15, right: 15); stack.addArrangedSubview(copy); button.addSubview(stack)
  NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: button.topAnchor), stack.leadingAnchor.constraint(equalTo: button.leadingAnchor), stack.trailingAnchor.constraint(equalTo: button.trailingAnchor), stack.bottomAnchor.constraint(equalTo: button.bottomAnchor)])
  button.accessibilityLabel = ([title, entry.date, linkedTrip].compactMap { $0 }).joined(separator: ", ")
  button.accessibilityIdentifier = "journal.card.\(entry.id)"
  button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
}
private func journalFieldGroup(_ title: String, control: UIView) -> UIView {
  let stack = UIStackView(arrangedSubviews: [coastLabel(title, size: 14), control]); stack.axis = .vertical; stack.spacing = 8; return stack
}
private func journalFormPanel(_ views: [UIView]) -> UIStackView {
  let panel = coastPanel(views, inset: 14); panel.backgroundColor = UIColor(hex: 0xF3F8FA); panel.layer.borderWidth = 0
  panel.heightAnchor.constraint(equalToConstant: 113).isActive = true; return panel
}
private func journalSelectButton(_ title: String, action: @escaping () -> Void) -> UIButton {
  let button = UIButton(type: .system); var config = UIButton.Configuration.plain(); config.title = title
  config.baseForegroundColor = CoastStyle.ink; config.background.backgroundColor = CoastStyle.inputFill; config.background.cornerRadius = 9
  config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
  config.image = UIImage(named: "icon-next"); config.imagePlacement = .trailing; config.imagePadding = 8
  config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in var result = incoming; result.font = CoastStyle.font(14); return result }
  button.configuration = config; button.contentHorizontalAlignment = .fill; button.heightAnchor.constraint(equalToConstant: 48).isActive = true
  button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
}
private func journalParagraph(lineHeight: CGFloat) -> NSParagraphStyle {
  let paragraph = NSMutableParagraphStyle(); paragraph.minimumLineHeight = lineHeight; paragraph.maximumLineHeight = lineHeight
  return paragraph
}
