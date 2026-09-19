import UIKit

final class TripsController: CoastController {
  var completed = false
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = iconItem("plus", label: env.t("Create trip", "创建出游")) {
      [weak self] in
      guard let self else { return }
      self.push(TripEditorController(self.env, trip: nil))
    }
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset()
    title = nil
    heading(env.t("Trips", "出游"))
    chips([env.t("Planned", "待出发"), env.t("Completed", "已完成")], selected: completed ? 1 : 0) {
      [weak self] i in
      self?.completed = i == 1
      self?.render()
    }
    let trips = env.store.ledger.trips.filter { $0.completed == completed }
    if trips.isEmpty {
      empty(
        env.t("Your next little adventure", "下一次小小的出走"),
        env.t("Make room for the experiences you love.", "把想去的地方和体验，放进一次出游。"), icon: "trips")
      add(
        coastButton(env.t("Create trip", "创建出游")) { [weak self] in
          guard let self else { return }
          self.push(TripEditorController(self.env, trip: nil))
        })
    }
    trips.forEach { trip in
      add(coastImage("camp", height: 210))
      add(
        row(
          title: trip.name,
          subtitle: trip.start.isEmpty
            ? env.t("No dates yet", "日期待定") : trip.start + " – " + trip.end
        ) { [weak self] in
          guard let self else { return }
          self.push(TripDetailController(self.env, id: trip.id))
        })
    }
  }
}
final class TripEditorController: CoastController {
  var trip: CoastTrip
  let original: CoastTrip?
  let pending: String?
  var name: UITextField!, start: UITextField!, end: UITextField!, notes: UITextView!,
    errorLabel = coastLabel("", size: 14, color: CoastStyle.red)
  init(_ env: CoastEnvironment, trip: CoastTrip?, pending: String? = nil) {
    self.trip = trip ?? CoastTrip(
      name: "", timeZone: env.store.preferences.region == "CN" ? "Asia/Shanghai" : "America/Los_Angeles")
    self.original = trip
    self.pending = pending
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    title = original == nil ? env.t("Create trip", "创建出游") : env.t("Edit trip", "编辑出游")
    navigationItem.hidesBackButton = true
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: env.t("Cancel", "取消"), primaryAction: UIAction { [weak self] _ in self?.cancel() })
    name = field(
      env.t("Trip name", "出游名称"), placeholder: env.t("Give your trip a name", "给出游起个名字"),
      value: trip.name, id: "trip.name")
    start = field(env.t("Start date", "开始日期"), placeholder: "YYYY-MM-DD", value: trip.start)
    end = field(env.t("End date", "结束日期"), placeholder: "YYYY-MM-DD", value: trip.end)
    start.keyboardType = .numbersAndPunctuation
    end.keyboardType = .numbersAndPunctuation
    notes = textArea(env.t("Notes", "备注"), value: trip.notes)
    errorLabel.isHidden = true
    add(errorLabel)
    add(coastButton(env.t("Save trip", "保存出游")) { [weak self] in self?.submit() })
    note(
      env.t(
        "Leave both dates blank if undecided. Existing activities keep their relative day.",
        "日期未定可同时留空。编辑日期会保留已有活动的相对天序。"))
  }
  func cancel() {
    let changed =
      name.text != trip.name || start.text != trip.start || end.text != trip.end
      || notes.text != trip.notes
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
      controllers.append(TripDetailController(env, id: trip.id))
      navigationController?.setViewControllers(controllers, animated: true)
      if let pending {
        navigationController?.pushViewController(
          ActivityPickerController(env, tripID: trip.id, pending: pending), animated: true)
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
    heading(trip.name)
    add(coastImage("camp", height: 170))
    note(trip.start.isEmpty ? env.t("No dates yet", "日期待定") : trip.start + " – " + trip.end)
    if trip.completed { note(env.t("Completed", "已完成出游")) }
    add(
      coastButton(env.t("Day ", "第 ") + "\(day+1)" + env.t("", " 天"), secondary: true) {
        [weak self] in self?.selectDay(trip)
      })
    for item in trip.items.filter({ $0.day == day }) {
      let content = env.item(item.activityID)
      add(
        row(
          title: content.map { env.text($0.title) } ?? item.titleSnapshot,
          subtitle: (item.time.map { $0 + " · " } ?? "")
            + (content.map { env.category($0.category) } ?? env.t("Original content unavailable", "原内容不可用")), image: content?.image
        ) { [weak self] in self?.itemMenu(item, trip: trip) })
    }
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
    guard let trip = env.store.ledger.trips.first(where: { $0.id == tripID }) else { return }
    add(
      coastButton(env.t("Day ", "第 ") + "\(day+1)" + env.t("", " 天"), secondary: true) {
        [weak self] in
        guard let self else { return }
        chooseTripDay(from: self, trip: trip, selected: self.day) { [weak self] selected in
          self?.day = selected
          self?.render()
        }
      })
    timeField = field(env.t("Time (optional)", "时间（选填）"), placeholder: "HH:mm", value: timeText)
    timeField?.keyboardType = .numbersAndPunctuation
    for item in env.catalog.items {
      add(
        row(
          title: (chosen == item.key ? "✓ " : "") + env.text(item.title),
          subtitle: env.category(item.category) + " · \(item.minutes) " + env.t("min", "分钟"),
          image: item.image
        ) { [weak self] in
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
  alert.addAction(UIAlertAction(title: controller.env.t("Choose", "选择"), style: .default) { [weak alert] _ in
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
