import UIKit

/// JO04 手记日历。按月浏览，圆点表示当天有手记；草稿不显示。
final class JournalCalendarController: CoastController {
  /// 以每月 1 日的本地零点表示当前月份。
  private var month: Date!
  private var selected: String?

  private let calendar: Calendar = {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = .current
    return value
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    month = startOfMonth(latestEntryDay() ?? CoastLedger.isoDay(Date()))
    NotificationCenter.default.addObserver(self, selector: #selector(syncChanged), name: FirebaseNoteSync.changed, object: nil)
  }
  @objc private func syncChanged() {
    if isViewLoaded, view.window != nil, navigationController?.topViewController === self { render() }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }

  // MARK: 日期工具

  private var published: [CoastEntry] {
    env.store.ledger.entries.filter { !$0.isDraft }
  }

  private func latestEntryDay() -> String? {
    published.map(\.date).max()
  }

  private func startOfMonth(_ day: String) -> Date {
    let parsed = CoastValidation.parseDate(day) ?? Date()
    let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: parsed)
    return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1))
      ?? Date()
  }

  private func isoDay(_ year: Int, _ monthValue: Int, _ day: Int) -> String {
    String(format: "%04d-%02d-%02d", year, monthValue, day)
  }

  private func counts() -> [String: Int] {
    let parts = calendar.dateComponents([.year, .month], from: month)
    guard let year = parts.year, let monthValue = parts.month else { return [:] }
    let prefix = String(format: "%04d-%02d", year, monthValue)
    var result: [String: Int] = [:]
    for entry in published where entry.date.hasPrefix(prefix) {
      result[entry.date, default: 0] += 1
    }
    return result
  }

  // MARK: 渲染

  private func render() {
    reset()
    title = env.t("Calendar", "日历")
    navigationItem.rightBarButtonItem = iconItem(
      "journal", label: env.t("List view", "列表视图")
    ) { [weak self] in self?.navigationController?.popViewController(animated: true) }
    contentTop.constant = 16
    stack.spacing = 12

    let marks = counts()
    let total = marks.values.reduce(0, +)
    add(monthHeader(total: total, days: marks.count))
    add(weekdayRow())
    add(grid(marks: marks))

    if let selected, let day = marks[selected], day > 0 {
      add(
        coastLabel(
          env.t("\(selected) · \(day) entries", "\(selected) · \(day) 篇"),
          size: 11, weight: .semibold, color: CoastStyle.brand, letterSpacing: 1.7))
      for entry in published.filter({ $0.date == selected }) {
        add(entryRow(entry))
      }
    } else if total > 0 {
      let hint = coastLabel(
        env.t(
          "Pick a marked day to read that day’s entries.", "点按带圆点的日期，查看当天的手记。"),
        size: 15, color: CoastStyle.muted)
      hint.textAlignment = .center
      add(hint)
    } else {
      let hint = coastLabel(
        env.t("No entries this month yet.", "本月还没有手记。"), size: 15, color: CoastStyle.muted)
      hint.textAlignment = .center
      add(hint)
    }
    add(
      coastNotice(
        env.t(
          "A dot marks a day with entries. Drafts are not shown here.",
          "圆点表示当天有手记；草稿不在日历中显示。")))
  }

  private func monthHeader(total: Int, days: Int) -> UIView {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: env.chinese ? "zh_Hans_CN" : "en_US")
    formatter.setLocalizedDateFormatFromTemplate("yMMMM")

    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 10
    row.alignment = .top
    let text = UIStackView()
    text.axis = .vertical
    text.spacing = 6
    text.addArrangedSubview(coastLabel(formatter.string(from: month), size: 23, weight: .bold))
    text.addArrangedSubview(
      coastLabel(
        env.t("\(total) entries · \(days) days", "本月 \(total) 篇 · \(days) 天有记录"),
        size: 13, color: CoastStyle.muted))
    row.addArrangedSubview(text)
    row.addArrangedSubview(UIView())
    row.addArrangedSubview(
      stepButton("back", label: env.t("Previous month", "上一月"), offset: -1))
    row.addArrangedSubview(stepButton("next", label: env.t("Next month", "下一月"), offset: 1))
    return row
  }

  private func stepButton(_ icon: String, label: String, offset: Int) -> UIButton {
    let button = UIButton(type: .system)
    button.setImage(UIImage(named: "icon-" + icon), for: .normal)
    button.tintColor = CoastStyle.brand
    button.accessibilityLabel = label
    button.widthAnchor.constraint(equalToConstant: 44).isActive = true
    button.heightAnchor.constraint(equalToConstant: 44).isActive = true
    button.addAction(
      UIAction { [weak self] _ in
        guard let self,
          let next = self.calendar.date(byAdding: .month, value: offset, to: self.month)
        else { return }
        self.month = next
        self.selected = nil
        self.render()
      }, for: .touchUpInside)
    return button
  }

  private func weekdayRow() -> UIView {
    // 周一开头，与设计稿的“一二三四五六日”一致。
    let names = env.chinese
      ? ["一", "二", "三", "四", "五", "六", "日"]
      : ["M", "T", "W", "T", "F", "S", "S"]
    let row = UIStackView()
    row.axis = .horizontal
    row.distribution = .fillEqually
    for name in names {
      let label = coastLabel(name, size: 11, color: CoastStyle.muted)
      label.textAlignment = .center
      row.addArrangedSubview(label)
    }
    row.isAccessibilityElement = false
    return row
  }

  private func grid(marks: [String: Int]) -> UIView {
    let parts = calendar.dateComponents([.year, .month], from: month)
    guard let year = parts.year, let monthValue = parts.month,
      let range = calendar.range(of: .day, in: .month, for: month)
    else { return UIView() }
    // 周一开头的前置空格数。
    let weekday = calendar.component(.weekday, from: month)  // 1 = 周日
    let lead = (weekday + 5) % 7
    let today = CoastLedger.isoDay(Date())

    let column = UIStackView()
    column.axis = .vertical
    column.spacing = 0
    var week = newWeek()
    for _ in 0..<lead { week.addArrangedSubview(UIView()) }
    for day in range {
      if week.arrangedSubviews.count == 7 {
        column.addArrangedSubview(week)
        week = newWeek()
      }
      let iso = isoDay(year, monthValue, day)
      week.addArrangedSubview(
        dayCell(day: day, iso: iso, count: marks[iso] ?? 0, isToday: iso == today))
    }
    while week.arrangedSubviews.count < 7 { week.addArrangedSubview(UIView()) }
    column.addArrangedSubview(week)
    return column
  }

  private func newWeek() -> UIStackView {
    let week = UIStackView()
    week.axis = .horizontal
    week.distribution = .fillEqually
    week.spacing = 0
    return week
  }

  private func dayCell(day: Int, iso: String, count: Int, isToday: Bool) -> UIView {
    let isSelected = iso == selected
    let button = UIButton(type: .system)
    button.isEnabled = count > 0
    let pill = UIView()
    pill.backgroundColor = isSelected ? CoastStyle.brand : .clear
    pill.layer.cornerRadius = 13
    pill.layer.borderWidth = isToday && !isSelected ? 1.5 : 0
    pill.layer.borderColor = CoastStyle.brand.cgColor
    pill.isUserInteractionEnabled = false
    pill.translatesAutoresizingMaskIntoConstraints = false
    let number = coastLabel(
      "\(day)", size: 15, weight: isSelected || isToday ? .semibold : .regular,
      color: isSelected ? .white : (count > 0 ? CoastStyle.ink : UIColor(hex: 0x8EA0A8)))
    number.textAlignment = .center
    number.translatesAutoresizingMaskIntoConstraints = false
    let dots = UIStackView()
    dots.axis = .horizontal
    dots.spacing = 3
    dots.alignment = .center
    dots.translatesAutoresizingMaskIntoConstraints = false
    for _ in 0..<min(count, 3) {
      let dot = UIView()
      dot.backgroundColor = isSelected ? .white : CoastStyle.brand
      dot.layer.cornerRadius = 2.5
      dot.widthAnchor.constraint(equalToConstant: 5).isActive = true
      dot.heightAnchor.constraint(equalToConstant: 5).isActive = true
      dots.addArrangedSubview(dot)
    }
    button.addSubview(pill)
    pill.addSubview(number)
    pill.addSubview(dots)
    NSLayoutConstraint.activate([
      button.heightAnchor.constraint(equalToConstant: 50),
      pill.centerXAnchor.constraint(equalTo: button.centerXAnchor),
      pill.centerYAnchor.constraint(equalTo: button.centerYAnchor),
      pill.widthAnchor.constraint(equalToConstant: 40),
      pill.heightAnchor.constraint(equalToConstant: 44),
      number.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
      number.topAnchor.constraint(equalTo: pill.topAnchor, constant: 6),
      dots.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
      dots.topAnchor.constraint(equalTo: number.bottomAnchor, constant: 3),
      dots.heightAnchor.constraint(equalToConstant: 5),
    ])
    button.accessibilityLabel =
      count > 0 ? iso + ", " + env.t("\(count) entries", "\(count) 篇") : iso
    button.accessibilityTraits = isSelected ? [.button, .selected] : [.button]
    button.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        self.selected = self.selected == iso ? nil : iso
        self.render()
      }, for: .touchUpInside)
    return button
  }

  private func entryRow(_ entry: CoastEntry) -> UIView {
    let trip = env.store.ledger.trips.first { $0.id == entry.tripID }?.name
    let detail = [trip, env.t("\(entry.photos.count) photos", "\(entry.photos.count) 张照片")]
      .compactMap { $0 }.joined(separator: " · ")
    let tags = entry.tagList.isEmpty ? nil : entry.tagList.joined(separator: " · ")
    let button = UIButton(type: .system)
    button.backgroundColor = .white
    button.layer.cornerRadius = 14
    button.layer.borderWidth = 1
    button.layer.borderColor = CoastStyle.border.cgColor
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 13
    row.alignment = .center
    row.isUserInteractionEnabled = false
    row.translatesAutoresizingMaskIntoConstraints = false

    let thumb = UIView()
    thumb.layer.cornerRadius = 9
    thumb.clipsToBounds = true
    thumb.widthAnchor.constraint(equalToConstant: 56).isActive = true
    thumb.heightAnchor.constraint(equalToConstant: 56).isActive = true
    if let first = entry.photos.first, let image = env.photo(first) {
      let view = UIImageView(image: image)
      view.contentMode = .scaleAspectFill
      view.clipsToBounds = true
      view.translatesAutoresizingMaskIntoConstraints = false
      thumb.addSubview(view)
      NSLayoutConstraint.activate([
        view.topAnchor.constraint(equalTo: thumb.topAnchor),
        view.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),
        view.leadingAnchor.constraint(equalTo: thumb.leadingAnchor),
        view.trailingAnchor.constraint(equalTo: thumb.trailingAnchor),
      ])
    } else {
      thumb.backgroundColor = CoastStyle.field
      let icon = UIImageView(image: UIImage(named: "icon-journal"))
      icon.tintColor = CoastStyle.brand
      icon.contentMode = .scaleAspectFit
      icon.translatesAutoresizingMaskIntoConstraints = false
      thumb.addSubview(icon)
      NSLayoutConstraint.activate([
        icon.widthAnchor.constraint(equalToConstant: 24),
        icon.heightAnchor.constraint(equalToConstant: 24),
        icon.centerXAnchor.constraint(equalTo: thumb.centerXAnchor),
        icon.centerYAnchor.constraint(equalTo: thumb.centerYAnchor),
      ])
    }
    row.addArrangedSubview(thumb)

    let text = UIStackView()
    text.axis = .vertical
    text.spacing = 4
    text.addArrangedSubview(
      coastLabel(
        entry.title.isEmpty ? env.t("Untitled entry", "未命名手记") : entry.title, size: 17,
        weight: .semibold))
    text.addArrangedSubview(coastLabel(detail, size: 13, color: CoastStyle.muted))
    if let tags {
      text.addArrangedSubview(coastLabel(tags, size: 11, weight: .medium, color: CoastStyle.brand))
    }
    row.addArrangedSubview(text)
    let chevron = UIImageView(image: UIImage(named: "icon-next"))
    chevron.tintColor = CoastStyle.brand
    chevron.contentMode = .scaleAspectFit
    chevron.widthAnchor.constraint(equalToConstant: 16).isActive = true
    row.addArrangedSubview(chevron)
    button.addSubview(row)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 11),
      row.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -11),
      row.topAnchor.constraint(equalTo: button.topAnchor, constant: 11),
      row.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -11),
    ])
    button.accessibilityLabel = [entry.title, detail, tags].compactMap { $0 }.joined(
      separator: ", ")
    button.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        self.push(JournalDetailController(self.env, id: entry.id))
      }, for: .touchUpInside)
    return button
  }
}
