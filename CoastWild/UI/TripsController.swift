import UIKit

final class TripsController: CoastController {
  var completed = false
  override func viewDidLoad() {
    super.viewDidLoad()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset()
    title = nil
    contentTop.constant = 16
    stack.spacing = 18
    add(editorRootHeader(env.t("Trips", "出游"), label: env.t("Create trip", "创建出游")) { [weak self] in
      guard let self else { return }
      self.push(TripEditorController(self.env, trip: nil))
    })
    stack.setCustomSpacing(20, after: stack.arrangedSubviews.last!)
    chips([env.t("Planned", "待出发"), env.t("Completed", "已完成")], selected: completed ? 1 : 0) {
      [weak self] i in
      self?.completed = i == 1
      self?.render()
    }
    let trips = env.store.ledger.trips.filter { $0.completed == completed }
    if trips.isEmpty {
      empty(env.t("Your next little adventure", "下一次小小的出走"),
        env.t("Make room for the experiences you love.", "把想去的地方和体验，放进一次出游。"),
        icon: "trips", actionTitle: env.t("Create trip", "创建出游")) { [weak self] in
          guard let self else { return }; self.push(TripEditorController(self.env, trip: nil))
        }
    }
    for (index, trip) in trips.enumerated() {
      let date = trip.start.isEmpty ? env.t("No dates yet", "日期待定") : trip.start + " – " + trip.end
      let count = "\(trip.items.count) " + env.t("experiences", "个体验")
      add(index == 0
        ? tripHeroCard(id: trip.id, title: trip.name, subtitle: date + " · " + count) { [weak self] in
            guard let self else { return }; self.push(TripDetailController(self.env, id: trip.id))
          }
        : row(title: trip.name, subtitle: date + "\n" + count, image: "camp") { [weak self] in
            guard let self else { return }; self.push(TripDetailController(self.env, id: trip.id))
          })
    }
  }
}
final class TripEditorController: CoastController {
  var trip: CoastTrip
  let original: CoastTrip?
  let pending: String?
  var selectedRegion: String
  var regionChanged = false
  var regionButton: UIButton!
  var name: UITextField!, start: UITextField!, end: UITextField!, notes: UITextView!,
    errorLabel = coastLabel("", size: 14, color: CoastStyle.red)
  init(_ env: CoastEnvironment, trip: CoastTrip?, pending: String? = nil) {
    self.trip =
      trip
      ?? CoastTrip(
        name: "",
        timeZone: env.store.preferences.region == "CN" ? "Asia/Shanghai" : "America/Los_Angeles")
    self.original = trip
    self.pending = pending
    self.selectedRegion = (trip?.timeZone == "Asia/Shanghai") ? "CN" : (trip == nil ? env.store.preferences.region : "US")
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    title = original == nil ? env.t("Create trip", "创建出游") : env.t("Edit trip", "编辑出游")
    navigationItem.hidesBackButton = true
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: env.t("Cancel", "取消"), primaryAction: UIAction { [weak self] _ in self?.cancel() })
    let saveItem = UIBarButtonItem(title: env.t("Save", "保存"), primaryAction: UIAction { [weak self] _ in self?.submit() })
    saveItem.accessibilityIdentifier = "trip.save"
    navigationItem.rightBarButtonItem = saveItem
    view.backgroundColor = UIColor(hex: 0xF3F8FA); scroll.backgroundColor = view.backgroundColor
    contentTop.constant = 20; stack.spacing = 14
    name = editorTextField(placeholder: env.t("Give your trip a name", "给出游起个名字"), value: trip.name)
    name.accessibilityIdentifier = "trip.name"
    add(editorFormPanel([editorFieldGroup(env.t("Trip name", "出游名称"), control: name)], height: 113))
    regionButton = editorSelectButton(regionTitle()) { [weak self] in self?.chooseRegion() }
    add(editorFormPanel([editorFieldGroup(env.t("Region", "地区"), control: regionButton)], height: 113))
    start = editorTextField(placeholder: "YYYY-MM-DD", value: trip.start)
    end = editorTextField(placeholder: "YYYY-MM-DD", value: trip.end)
    add(editorFormPanel([
      editorFieldGroup(env.t("Start date", "开始日期"), control: start),
      editorFieldGroup(env.t("End date", "结束日期"), control: end),
    ], spacing: 18, height: 210))
    start.keyboardType = .numbersAndPunctuation
    end.keyboardType = .numbersAndPunctuation
    notes = editorTextArea(placeholder: env.t("Write down your thoughts for this trip…", "写下这次出游的想法…"), value: trip.notes, height: 105)
    add(editorFormPanel([editorFieldGroup(env.t("Notes", "备注"), control: notes)], height: 170))
    errorLabel.isHidden = true
    add(errorLabel)
    note(
      env.t(
        "Leave both dates blank if undecided. Existing activities keep their relative day.",
        "日期未定可同时留空。编辑日期会保留已有活动的相对天序。"))
  }
  func regionTitle() -> String { selectedRegion == "CN" ? env.t("Mainland China", "中国大陆") : env.t("United States", "美国") }
  func chooseRegion() {
    menu(env.t("Region", "地区"), choices: [
      (env.t("United States", "美国"), { [weak self] in self?.setRegion("US") }),
      (env.t("Mainland China", "中国大陆"), { [weak self] in self?.setRegion("CN") }),
    ])
  }
  func setRegion(_ region: String) {
    selectedRegion = region; regionChanged = true; regionButton.accessibilityValue = regionTitle()
    regionButton.configuration?.title = regionTitle()
  }
  func cancel() {
    let changed =
      name.text != trip.name || start.text != trip.start || end.text != trip.end
      || notes.text != trip.notes || regionChanged
    if changed {
      confirm(
        env.t("Discard changes?", "放弃本次修改？"), env.t("Unsaved edits will be lost.", "未保存的修改将丢失。")
      ) { [weak self] in self?.navigationController?.popViewController(animated: true) }
    } else {
      navigationController?.popViewController(animated: true)
    }
  }
  func submit() {
    trip.name = name.text ?? ""
    trip.start = start.text ?? ""
    trip.end = end.text ?? ""
    trip.notes = notes.text ?? ""
    if original == nil || regionChanged { trip.timeZone = selectedRegion == "CN" ? "Asia/Shanghai" : "America/Los_Angeles" }
    if let issue = CoastValidation.trip(trip) {
      errorLabel.text =
        env.t(
          "Check the name (1–60), both dates and notes (up to 1000).",
          "请检查名称（1–60 字）、起止日期和备注（最多 1000 字）。") + "\n" + env.errorText(CoastStoreError(issue))
      errorLabel.isHidden = false
      return
    }
    if save({ try env.store.saveTrip(trip) }) {
      var controllers = navigationController?.viewControllers ?? []
      controllers.removeLast()
      let detail = TripDetailController(env, id: trip.id)
      detail.hidesBottomBarWhenPushed = true
      controllers.append(detail)
      navigationController?.setViewControllers(controllers, animated: true)
      if let pending {
        let picker = ActivityPickerController(env, tripID: trip.id, pending: pending)
        picker.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(picker, animated: true)
      }
    }
  }
}
final class TripDetailController: CoastController {
  let id: String
  var day = 0
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
    guard let trip = env.store.ledger.trips.first(where: { $0.id == id }) else {
      navigationController?.popViewController(animated: true)
      return
    }
    title = env.t("Trips", "出游")
    navigationItem.rightBarButtonItem = iconItem("edit", label: env.t("Edit trip", "编辑出游")) {
      [weak self] in
      guard let self else { return }
      self.push(TripEditorController(self.env, trip: trip))
    }
    contentTop.constant = 27; stack.spacing = 14
    add(coastLabel(trip.name, size: 27, weight: .bold))
    add(coastImage("camp", height: 163))
    note(trip.start.isEmpty ? env.t("No dates yet", "日期待定") : trip.start + " – " + trip.end)
    if trip.completed { note(env.t("Completed", "已完成出游")) }
    let days = tripDayCount(trip)
    if days <= 7 {
      let dayTitles = (0..<days).map { env.t("Day ", "第 ") + "\($0 + 1)" + env.t("", " 天") }
      chips(dayTitles, selected: min(day, days - 1)) { [weak self] value in self?.day = value; self?.render() }
    } else {
      add(coastButton(env.t("Day ", "第 ") + "\(day + 1)" + env.t("", " 天"), secondary: true) { [weak self] in self?.selectDay(trip) })
    }
    let timeline = UIStackView(); timeline.axis = .vertical; timeline.spacing = 0
    for item in trip.items.filter({ $0.day == day }) {
      let content = env.item(item.activityID)
      timeline.addArrangedSubview(timelineRow(id: item.id, time: item.time ?? "—", title: content.map { env.text($0.title) } ?? item.titleSnapshot,
        category: content.map { env.category($0.category) } ?? env.t("Original content unavailable", "原内容不可用"),
        categoryKey: content?.category, optionsLabel: env.t("Options for ", "更多选项：") + item.titleSnapshot) { [weak self] in self?.itemMenu(item, trip: trip) })
    }
    if !timeline.arrangedSubviews.isEmpty { add(timeline) }
    add(
      coastButton(env.t("Add experience", "添加体验"), secondary: true) { [weak self] in
        guard let self else { return }
        self.push(ActivityPickerController(self.env, tripID: self.id, initialDay: self.day))
      })
    add(
      coastButton(env.t("Write a journal entry", "写一篇手记")) { [weak self] in
        guard let self else { return }
        self.push(JournalEditorController(self.env, entry: nil, tripID: self.id))
      })
    add(
      coastButton(env.t("More options", "更多选项"), secondary: true) { [weak self] in self?.more(trip)
      })
    if !trip.notes.isEmpty { note(trip.notes) }
    let entries = env.store.ledger.entries.filter { !$0.isDraft && $0.tripID == trip.id }
    if !entries.isEmpty {
      add(coastLabel(env.t("Journal entries", "这次出游的回忆"), size: 23, weight: .bold))
      for entry in entries {
        add(tripJournalCard(entry: entry, image: entry.photos.first.flatMap { env.photo($0) }, tripName: trip.name) { [weak self] in
          guard let self else { return }; self.push(JournalDetailController(self.env, id: entry.id))
        })
      }
    }
  }
  func selectDay(_ trip: CoastTrip) {
    chooseTripDay(from: self, trip: trip, selected: day) { [weak self] selected in
      self?.day = selected
      self?.render()
    }
  }
  func itemMenu(_ item: CoastTripItem, trip: CoastTrip) {
    menu(
      item.titleSnapshot,
      choices: [
        (
          env.t("View experience", "查看体验"),
          { [weak self] in
            guard let self, let content = self.env.item(item.activityID) else { return }
            self.push(ContentController(self.env, item: content))
          }
        ),
        (env.t("Change day", "更改日期"), { [weak self] in self?.changeDay(item, trip: trip) }),
        (env.t("Move up", "上移"), { [weak self] in self?.move(item, trip: trip, offset: -1) }),
        (env.t("Move down", "下移"), { [weak self] in self?.move(item, trip: trip, offset: 1) }),
        (
          env.t("Remove from trip", "从出游移除"),
          { [weak self] in
            guard let self else { return }
            var next = trip
            next.items.removeAll { $0.id == item.id }
            if self.save({ try self.env.store.saveTrip(next) }) { self.render() }
          }
        ),
      ])
  }
  func changeDay(_ item: CoastTripItem, trip: CoastTrip) {
    chooseTripDay(from: self, trip: trip, selected: item.day) { [weak self] targetDay in
      guard let self, targetDay != item.day,
        let index = trip.items.firstIndex(where: { $0.id == item.id })
      else { return }
      var next = trip
      next.items[index].day = targetDay
      if self.save({ try self.env.store.saveTrip(next) }) {
        self.day = targetDay
        self.render()
      }
    }
  }
  func move(_ item: CoastTripItem, trip: CoastTrip, offset: Int) {
    var next = trip
    let indices = next.items.indices.filter { next.items[$0].day == item.day }
    guard let current = indices.firstIndex(where: { next.items[$0].id == item.id }),
      indices.indices.contains(current + offset)
    else { return }
    next.items.swapAt(indices[current], indices[current + offset])
    if save({ try env.store.saveTrip(next) }) { render() }
  }
  func more(_ trip: CoastTrip) {
    menu(
      env.t("Trip options", "出游选项"),
      choices: [
        (
          trip.completed ? env.t("Reopen trip", "重新打开出游") : env.t("Complete trip", "结束出游"),
          { [weak self] in
            guard let self else { return }
            var next = trip
            next.completed.toggle()
            if self.save({ try self.env.store.saveTrip(next) }) { self.render() }
          }
        ),
        (
          env.t("Delete trip", "删除出游"),
          { [weak self] in
            guard let self else { return }
            self.confirm(
              self.env.t("Delete this trip?", "删除这次出游？"),
              self.env.t("Journal entries will be kept and unlinked.", "关联手记会保留，并解除与出游的关联。")
            ) {
              if self.save({ try self.env.store.deleteTrip(id: trip.id) }) {
                self.navigationController?.popViewController(animated: true)
              }
            }
          }
        ),
      ])
  }
}
func tripDayCount(_ trip: CoastTrip) -> Int {
  let f = DateFormatter()
  f.dateFormat = "yyyy-MM-dd"
  f.locale = Locale(identifier: "en_US_POSIX")
  f.timeZone = TimeZone(secondsFromGMT: 0)
  guard let start = f.date(from: trip.start), let end = f.date(from: trip.end) else { return 1 }
  return max(1, Int(end.timeIntervalSince(start) / 86400) + 1)
}
final class ActivityPickerController: CoastController {
  let tripID: String
  var chosen: String?
  var timeText = ""
  var timeField: UITextField?
  var day: Int
  init(_ env: CoastEnvironment, tripID: String, pending: String? = nil, initialDay: Int = 0) {
    self.tripID = tripID
    chosen = pending
    day = initialDay
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }
  func render() {
    timeText = timeField?.text ?? timeText
    reset()
    title = env.t("Add experience", "添加体验")
    contentTop.constant = 27; stack.spacing = 12
    guard let trip = env.store.ledger.trips.first(where: { $0.id == tripID }) else { return }
    add(coastLabel(env.t("Add experience", "添加体验"), size: 17, weight: .bold))
    add(editorFieldGroup(env.t("Date", "日期"), control:
      coastSettingRow(env.t("Day ", "第 ") + "\(day+1)" + env.t("", " 天"), value: nil) {
        [weak self] in
        guard let self else { return }
        chooseTripDay(from: self, trip: trip, selected: self.day) { [weak self] selected in
          self?.day = selected
          self?.render()
        }
      }))
    timeField = editorTextField(placeholder: "HH:mm", value: timeText)
    add(editorFieldGroup(env.t("Time (optional)", "时间（选填）"), control: timeField!))
    timeField?.keyboardType = .numbersAndPunctuation
    for item in env.catalog.items {
      add(pickerCard(id: item.key, title: env.text(item.title),
          subtitle: env.category(item.category) + " · \(item.minutes) " + env.t("min", "分钟"), image: item.image,
          selected: chosen == item.key) { [weak self] in
          self?.chosen = item.key
          self?.render()
        })
    }
    add(
      coastButton(env.t("Add to trip", "加入出游")) { [weak self] in
        guard let self, let chosen = self.chosen, let item = self.env.item(chosen) else { return }
        if trip.items.contains(where: { $0.activityID == chosen && $0.day == self.day }) {
          self.message(
            self.env.t("Already added", "已经添加过了"),
            self.env.t("Choose a different day or experience.", "当天已添加此体验，请选择其他体验或日期。"))
          return
        }
        if self.save({
          var next = trip
          let time = self.timeField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          next.items.append(
            CoastTripItem(
              activityID: chosen, day: self.day, titleSnapshot: self.env.text(item.title),
              time: time.isEmpty ? nil : time))
          try self.env.store.saveTrip(next)
        }) {
          self.navigationController?.popViewController(animated: true)
        }
      })
  }
}

private func editorRootHeader(_ title: String, label: String, action: @escaping () -> Void) -> UIView {
  let row = UIStackView(); row.axis = .horizontal; row.alignment = .center
  row.addArrangedSubview(coastLabel(title, size: 32, weight: .bold)); row.addArrangedSubview(UIView())
  let button = UIButton(type: .system); button.setImage(UIImage(systemName: "plus"), for: .normal)
  button.tintColor = CoastStyle.ink; button.backgroundColor = CoastStyle.sand; button.layer.cornerRadius = 22
  button.widthAnchor.constraint(equalToConstant: 44).isActive = true; button.heightAnchor.constraint(equalToConstant: 44).isActive = true
  button.accessibilityLabel = label; button.addAction(UIAction { _ in action() }, for: .touchUpInside); row.addArrangedSubview(button)
  return row
}
private func tripHeroCard(id: String, title: String, subtitle: String, action: @escaping () -> Void) -> UIView {
  let button = UIButton(type: .system); button.backgroundColor = .white; button.layer.borderWidth = 1
  button.layer.borderColor = CoastStyle.border.cgColor; button.layer.cornerRadius = 16; button.clipsToBounds = true
  let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 0; stack.isUserInteractionEnabled = false; stack.translatesAutoresizingMaskIntoConstraints = false
  let image = coastImage("camp", height: 264); image.layer.cornerRadius = 0; stack.addArrangedSubview(image)
  let copy = UIStackView(arrangedSubviews: [coastLabel(title, size: 24, weight: .bold), coastLabel(subtitle, size: 13, color: CoastStyle.muted)])
  copy.axis = .vertical; copy.spacing = 5; copy.isLayoutMarginsRelativeArrangement = true; copy.layoutMargins = UIEdgeInsets(top: 10, left: 15, bottom: 12, right: 15)
  stack.addArrangedSubview(copy); button.addSubview(stack)
  NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: button.topAnchor), stack.leadingAnchor.constraint(equalTo: button.leadingAnchor), stack.trailingAnchor.constraint(equalTo: button.trailingAnchor), stack.bottomAnchor.constraint(equalTo: button.bottomAnchor)])
  button.accessibilityLabel = title + ", " + subtitle; button.accessibilityIdentifier = "trip.card.\(id)"
  button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
}
private func editorTextField(placeholder: String, value: String) -> UITextField {
  let field = UITextField(); field.text = value; field.attributedPlaceholder = NSAttributedString(string: placeholder,
    attributes: [.foregroundColor: UIColor(hex: 0x757575), .font: CoastStyle.font(14)]); field.font = CoastStyle.font(14)
  field.backgroundColor = CoastStyle.inputFill; field.layer.cornerRadius = 9; field.heightAnchor.constraint(equalToConstant: 48).isActive = true
  field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1)); field.leftViewMode = .always; return field
}
private func editorTextArea(placeholder: String, value: String, height: CGFloat) -> UITextView {
  let field = UITextView(); field.text = value; field.font = CoastStyle.font(14); field.backgroundColor = CoastStyle.inputFill
  field.layer.cornerRadius = 9; field.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
  field.heightAnchor.constraint(equalToConstant: height).isActive = true; field.accessibilityLabel = placeholder; return field
}
private func editorFieldGroup(_ title: String, control: UIView) -> UIView {
  let stack = UIStackView(arrangedSubviews: [coastLabel(title, size: 14), control]); stack.axis = .vertical; stack.spacing = 8; return stack
}
private func editorFormPanel(_ views: [UIView], spacing: CGFloat = 16, height: CGFloat) -> UIStackView {
  let panel = coastPanel(views, spacing: spacing, inset: 14); panel.layer.borderWidth = 0
  panel.heightAnchor.constraint(equalToConstant: height).isActive = true; return panel
}
private func editorSelectButton(_ title: String, action: @escaping () -> Void) -> UIButton {
  let button = UIButton(type: .system); var config = UIButton.Configuration.plain(); config.title = title
  config.baseForegroundColor = CoastStyle.ink; config.background.backgroundColor = CoastStyle.inputFill; config.background.cornerRadius = 9
  config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
  config.image = UIImage(named: "icon-next"); config.imagePlacement = .trailing; config.imagePadding = 8
  config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in var result = incoming; result.font = CoastStyle.font(14); return result }
  button.configuration = config; button.contentHorizontalAlignment = .fill; button.heightAnchor.constraint(equalToConstant: 48).isActive = true
  button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
}
private func timelineRow(id: String, time: String, title: String, category: String, categoryKey: String?, optionsLabel: String, action: @escaping () -> Void) -> UIView {
  let container = UIView(); container.heightAnchor.constraint(equalToConstant: 64).isActive = true
  let row = UIStackView(); row.axis = .horizontal; row.spacing = 10; row.alignment = .center; row.translatesAutoresizingMaskIntoConstraints = false
  let timeLabel = coastLabel(time, size: 12); timeLabel.widthAnchor.constraint(equalToConstant: 42).isActive = true; row.addArrangedSubview(timeLabel)
  let badge = UIView(); badge.backgroundColor = UIColor(hex: categoryKey == "surf" ? 0xDFF0F4 : 0xF9EDD5); badge.layer.cornerRadius = 21
  badge.widthAnchor.constraint(equalToConstant: 42).isActive = true; badge.heightAnchor.constraint(equalToConstant: 42).isActive = true
  let iconName = categoryKey == "surf" ? "wave" : (categoryKey ?? "info")
  let iv = UIImageView(image: UIImage(named: "icon-" + iconName)); iv.contentMode = .scaleAspectFit; iv.tintColor = CoastStyle.brand; iv.translatesAutoresizingMaskIntoConstraints = false; badge.addSubview(iv)
  NSLayoutConstraint.activate([iv.centerXAnchor.constraint(equalTo: badge.centerXAnchor), iv.centerYAnchor.constraint(equalTo: badge.centerYAnchor), iv.widthAnchor.constraint(equalToConstant: 24), iv.heightAnchor.constraint(equalToConstant: 24)])
  row.addArrangedSubview(badge)
  let copy = UIStackView(arrangedSubviews: [coastLabel(title, size: 14, weight: .bold), coastLabel(category, size: 12, color: CoastStyle.muted)])
  copy.axis = .vertical; copy.spacing = 3; row.addArrangedSubview(copy)
  let options = UIButton(type: .system); options.setImage(UIImage(named: "icon-more"), for: .normal); options.tintColor = CoastStyle.brand
  options.widthAnchor.constraint(equalToConstant: 32).isActive = true; options.heightAnchor.constraint(equalToConstant: 44).isActive = true
  options.accessibilityLabel = optionsLabel; options.accessibilityIdentifier = "trip.timeline.options.\(id)"
  options.addAction(UIAction { _ in action() }, for: .touchUpInside); row.addArrangedSubview(options); container.addSubview(row)
  NSLayoutConstraint.activate([row.topAnchor.constraint(equalTo: container.topAnchor), row.bottomAnchor.constraint(equalTo: container.bottomAnchor), row.leadingAnchor.constraint(equalTo: container.leadingAnchor), row.trailingAnchor.constraint(equalTo: container.trailingAnchor)])
  return container
}
private func pickerCard(id: String, title: String, subtitle: String, image: String, selected: Bool, action: @escaping () -> Void) -> UIView {
  let button = UIButton(type: .system); button.backgroundColor = .white; button.layer.cornerRadius = 14; button.layer.borderWidth = 1; button.layer.borderColor = CoastStyle.border.cgColor
  button.heightAnchor.constraint(equalToConstant: 91).isActive = true
  let row = UIStackView(); row.axis = .horizontal; row.spacing = 13; row.alignment = .center; row.isUserInteractionEnabled = false; row.translatesAutoresizingMaskIntoConstraints = false
  let iv = coastImage(image, height: 67); iv.widthAnchor.constraint(equalToConstant: 68).isActive = true; iv.layer.cornerRadius = 10; row.addArrangedSubview(iv)
  let copy = UIStackView(arrangedSubviews: [coastLabel(title, size: 17, weight: .bold), coastLabel(subtitle, size: 13, color: CoastStyle.muted)]); copy.axis = .vertical; copy.spacing = 5; row.addArrangedSubview(copy)
  let next = UIImageView(image: UIImage(named: "icon-next")); next.tintColor = CoastStyle.muted; next.widthAnchor.constraint(equalToConstant: 16).isActive = true; next.heightAnchor.constraint(equalToConstant: 16).isActive = true; row.addArrangedSubview(next)
  button.addSubview(row); NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12), row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12), row.centerYAnchor.constraint(equalTo: button.centerYAnchor)])
  button.accessibilityLabel = title + ", " + subtitle; button.accessibilityIdentifier = "trip.activity.\(id)"
  button.accessibilityTraits = selected ? [.button, .selected] : [.button]
  button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
}
private func tripJournalCard(entry: CoastEntry, image: UIImage?, tripName: String, action: @escaping () -> Void) -> UIView {
  let button = UIButton(type: .system); button.backgroundColor = .white; button.layer.cornerRadius = 15; button.layer.borderWidth = 1; button.layer.borderColor = CoastStyle.border.cgColor; button.clipsToBounds = true
  let stack = UIStackView(); stack.axis = .vertical; stack.translatesAutoresizingMaskIntoConstraints = false; stack.isUserInteractionEnabled = false
  if let image { let iv = UIImageView(image: image); iv.contentMode = .scaleAspectFill; iv.clipsToBounds = true; iv.heightAnchor.constraint(equalToConstant: 210).isActive = true; stack.addArrangedSubview(iv) }
  let title = entry.title.isEmpty ? "—" : entry.title; let copy = UIStackView(arrangedSubviews: [coastLabel(entry.date, size: 13, color: CoastStyle.muted), coastLabel(title, size: 22, weight: .bold), coastLabel(entry.body, size: 14, color: CoastStyle.muted), coastLabel(tripName, size: 13, color: CoastStyle.muted)])
  copy.axis = .vertical; copy.spacing = 6; copy.isLayoutMarginsRelativeArrangement = true; copy.layoutMargins = UIEdgeInsets(top: 13, left: 15, bottom: 15, right: 15); stack.addArrangedSubview(copy); button.addSubview(stack)
  NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: button.topAnchor), stack.leadingAnchor.constraint(equalTo: button.leadingAnchor), stack.trailingAnchor.constraint(equalTo: button.trailingAnchor), stack.bottomAnchor.constraint(equalTo: button.bottomAnchor)])
  button.accessibilityLabel = [title, entry.date, tripName].joined(separator: ", ")
  button.accessibilityIdentifier = "trip.journal.\(entry.id)"
  button.addAction(UIAction { _ in action() }, for: .touchUpInside); return button
}

private func chooseTripDay(
  from controller: CoastController, trip: CoastTrip, selected: Int,
  onSelect: @escaping (Int) -> Void
) {
  let count = tripDayCount(trip)
  if count <= 14 {
    controller.menu(
      controller.env.t("Choose day", "选择日期"),
      choices: (0..<count).map { day in
        (
          controller.env.t("Day ", "第 ") + "\(day + 1)" + controller.env.t("", " 天"),
          { onSelect(day) }
        )
      })
    return
  }
  let alert = UIAlertController(
    title: controller.env.t("Choose day", "选择日期"),
    message: controller.env.t("Enter a day from 1 to \(count).", "请输入 1 至 \(count) 之间的天数。"),
    preferredStyle: .alert)
  alert.addTextField { field in
    field.keyboardType = .numberPad
    field.text = "\(selected + 1)"
    field.selectAll(nil)
  }
  alert.addAction(UIAlertAction(title: controller.env.t("Cancel", "取消"), style: .cancel))
  alert.addAction(
    UIAlertAction(title: controller.env.t("Choose", "选择"), style: .default) { [weak alert] _ in
      guard let text = alert?.textFields?.first?.text,
        let value = Int(text), (1...count).contains(value)
      else {
        controller.message(
          controller.env.t("Invalid day", "日期无效"),
          controller.env.t("Enter a day from 1 to \(count).", "请输入 1 至 \(count) 之间的天数。"))
        return
      }
      onSelect(value - 1)
    })
  controller.present(alert, animated: true)
}
