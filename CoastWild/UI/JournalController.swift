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
    add(journalRootHeader(env.t("Journal", "手记"), label: env.t("New entry", "新手记")) { [weak self] in
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
  let original: CoastEntry?
  var titleField: UITextField!, dateField: UITextField!, bodyField: UITextView!,
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
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: env.t("Save", "保存"), primaryAction: UIAction { [weak self] _ in self?.submit() })
    contentTop.constant = 23; stack.spacing = 14
    titleField = UITextField(); titleField.text = entry.title
    titleField.placeholder = env.t("Give your memory a name", "给回忆起个名字")
    titleField.font = CoastStyle.font(26, .bold); titleField.textColor = CoastStyle.ink
    titleField.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
    titleField.accessibilityIdentifier = "journal.title"; add(titleField)
    stack.setCustomSpacing(31, after: titleField)
    dateField = journalTextField(value: entry.date)
    dateField.accessibilityLabel = env.t("Date", "日期"); add(dateField)
    stack.setCustomSpacing(24, after: dateField)
    dateField.keyboardType = .numbersAndPunctuation
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
    tripButton = journalSelectButton(tripTitle()) { [weak self] in self?.chooseTrip() }
    add(journalFormPanel([journalFieldGroup(env.t("Link a trip", "关联出游"), control: tripButton)]))
    activityButton = UIButton(type: .system)
    status.font = CoastStyle.font(12)
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
    if original == nil && entry.title.isEmpty && entry.body.isEmpty && entry.photos.isEmpty {
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

private func journalRootHeader(_ title: String, label: String, action: @escaping () -> Void) -> UIView {
  let row = UIStackView(); row.axis = .horizontal; row.alignment = .center
  row.addArrangedSubview(coastLabel(title, size: 32, weight: .bold)); row.addArrangedSubview(UIView())
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
  button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
}
private func journalTextField(value: String) -> UITextField {
  let field = UITextField(); field.text = value; field.font = CoastStyle.font(14); field.backgroundColor = CoastStyle.inputFill
  field.layer.cornerRadius = 9; field.heightAnchor.constraint(equalToConstant: 48).isActive = true
  field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1)); field.leftViewMode = .always; return field
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
