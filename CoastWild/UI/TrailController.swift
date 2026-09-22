import UIKit

/// ME02 足迹。全部从本机当前账号的账本派生，不落盘，不上传。
final class TrailController: CoastController {
  private var year: Int?

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }

  private func render() {
    reset()
    title = env.t("Your trail", "足迹")
    contentTop.constant = 16
    stack.spacing = 14

    let stats = env.store.ledger.trailStats(year: year) { [env] id in
      env.item(id)?.category
    }
    let years = Array(stats.years.prefix(2))
    if !years.isEmpty {
      let titles = [env.t("All", "全部")] + years.map(String.init)
      let selected = year.flatMap { years.firstIndex(of: $0).map { $0 + 1 } } ?? 0
      chips(titles, selected: selected) { [weak self] index in
        self?.year = index == 0 ? nil : years[index - 1]
        self?.render()
      }
    }

    if stats.isEmpty {
      empty(
        env.t("Your trail starts here", "足迹从这里开始"),
        env.t(
          "Plan a trip or write an entry, and your counts, months and milestones appear here.",
          "创建一次出游或写一篇手记，这里就会出现计数、月份与里程碑。"),
        icon: "trips", actionTitle: env.t("Create a trip", "创建出游")
      ) { [weak self] in
        guard let self else { return }
        self.push(TripEditorController(self.env, trip: nil))
      }
      return
    }

    add(
      coastStats([
        ("\(stats.trips)", env.t("Trips", "出游")),
        ("\(stats.entries)", env.t("Entries", "手记")),
        ("\(stats.photos)", env.t("Photos", "照片")),
      ]))

    add(sectionLabel(env.t("Experience mix", "体验分布")))
    let peak = max(1, stats.categories.map(\.count).max() ?? 1)
    for item in stats.categories {
      add(distributionRow(env.gearGroupName(item.key), count: item.count, ratio: Double(item.count) / Double(peak)))
    }

    add(sectionLabel(env.t("By month", "按月")))
    add(monthChart(stats.months))

    add(sectionLabel(env.t("Milestones", "里程碑")))
    add(badgeGrid(stats))

    add(
      coastNotice(
        env.t(
          "Counts come from this account on this device only. Nothing is uploaded.",
          "统计只根据本机当前账号的数据计算，不含其他设备，也不会上传。")))
  }

  private func sectionLabel(_ text: String) -> UILabel {
    coastLabel(
      text.uppercased(), size: 11, weight: .semibold, color: CoastStyle.brand, letterSpacing: 1.7)
  }

  private func distributionRow(_ name: String, count: Int, ratio: Double) -> UIView {
    let group = UIStackView()
    group.axis = .vertical
    group.spacing = 8
    let line = UIStackView()
    line.axis = .horizontal
    line.alignment = .firstBaseline
    line.addArrangedSubview(coastLabel(name, size: 15, weight: .medium))
    line.addArrangedSubview(UIView())
    let times = env.t("\(count) times", "\(count) 次")
    line.addArrangedSubview(coastLabel(times, size: 13, color: CoastStyle.muted))
    group.addArrangedSubview(line)
    let track = UIView()
    track.backgroundColor = UIColor(hex: 0xE5EDF0)
    track.layer.cornerRadius = 4
    track.heightAnchor.constraint(equalToConstant: 8).isActive = true
    let fill = UIView()
    fill.backgroundColor = CoastStyle.brand
    fill.layer.cornerRadius = 4
    fill.translatesAutoresizingMaskIntoConstraints = false
    track.addSubview(fill)
    NSLayoutConstraint.activate([
      fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
      fill.topAnchor.constraint(equalTo: track.topAnchor),
      fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
      fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: max(0.001, ratio)),
    ])
    group.addArrangedSubview(track)
    group.isAccessibilityElement = true
    group.accessibilityLabel = name + ", " + times
    return group
  }

  private func monthChart(_ months: [Int]) -> UIView {
    let peak = max(1, months.max() ?? 1)
    let row = UIStackView()
    row.axis = .horizontal
    row.distribution = .fillEqually
    row.alignment = .bottom
    row.spacing = 4
    for (index, count) in months.enumerated() {
      let column = UIStackView()
      column.axis = .vertical
      column.alignment = .center
      column.spacing = 6
      let bar = UIView()
      bar.backgroundColor = count > 0 ? CoastStyle.brand : UIColor(hex: 0xE5EDF0)
      bar.layer.cornerRadius = 4
      let height = count > 0 ? max(6, 92 * Double(count) / Double(peak)) : 3
      bar.heightAnchor.constraint(equalToConstant: height).isActive = true
      bar.widthAnchor.constraint(lessThanOrEqualToConstant: 16).isActive = true
      let holder = UIView()
      holder.addSubview(bar)
      bar.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        bar.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
        bar.widthAnchor.constraint(equalTo: holder.widthAnchor),
        bar.topAnchor.constraint(equalTo: holder.topAnchor),
        bar.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
      ])
      column.addArrangedSubview(holder)
      column.addArrangedSubview(coastLabel("\(index + 1)", size: 11, color: CoastStyle.muted))
      row.addArrangedSubview(column)
    }
    let container = UIView()
    row.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(row)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      row.topAnchor.constraint(equalTo: container.topAnchor),
      row.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      container.heightAnchor.constraint(greaterThanOrEqualToConstant: 122),
    ])
    container.isAccessibilityElement = true
    container.accessibilityLabel = env.t("Entries by month", "按月手记数")
    container.accessibilityValue =
      months.enumerated().filter { $0.element > 0 }
      .map { env.t("month \($0.offset + 1): \($0.element)", "\($0.offset + 1) 月 \($0.element) 篇") }
      .joined(separator: ", ")
    return container
  }

  private func badgeGrid(_ stats: CoastTrailStats) -> UIView {
    let entries: [(String, String, CoastTrailStats.Badge, String)] = [
      (
        "wave", env.t("First lesson", "首课完成"), stats.firstLesson,
        env.t("Finish any lesson", "完成任意一课")
      ),
      (
        "trips", env.t("Three day trip", "三日出游"), stats.threeDayTrip,
        env.t("Finish a trip of 3+ days", "完成跨度 3 天以上的出游")
      ),
      (
        "journal", env.t("Seven in a row", "连续 7 天"), stats.streak7,
        env.t("Best so far: \(stats.streakLength) days", "目前最长 \(stats.streakLength) 天")
      ),
    ]
    let row = UIStackView()
    row.axis = .horizontal
    row.distribution = .fillEqually
    row.spacing = 12
    row.alignment = .fill
    for (icon, name, badge, hint) in entries {
      row.addArrangedSubview(badgeTile(icon: icon, name: name, badge: badge, hint: hint))
    }
    return row
  }

  private func badgeTile(icon: String, name: String, badge: CoastTrailStats.Badge, hint: String)
    -> UIView
  {
    let card = UIStackView()
    card.axis = .vertical
    card.alignment = .center
    card.spacing = 6
    card.isLayoutMarginsRelativeArrangement = true
    card.layoutMargins = UIEdgeInsets(top: 14, left: 8, bottom: 14, right: 8)
    card.backgroundColor = .white
    card.layer.cornerRadius = 14
    card.layer.borderWidth = 1
    card.layer.borderColor = CoastStyle.border.cgColor
    let circle = UIView()
    circle.backgroundColor = badge.unlocked ? UIColor(hex: 0xFBEED8) : UIColor(hex: 0xF0F4F5)
    circle.layer.cornerRadius = 22
    circle.widthAnchor.constraint(equalToConstant: 44).isActive = true
    circle.heightAnchor.constraint(equalToConstant: 44).isActive = true
    let image = UIImageView(image: UIImage(named: "icon-" + icon))
    image.tintColor = badge.unlocked ? UIColor(hex: 0x8A6524) : UIColor(hex: 0x9AA8AE)
    image.contentMode = .scaleAspectFit
    image.translatesAutoresizingMaskIntoConstraints = false
    circle.addSubview(image)
    NSLayoutConstraint.activate([
      image.widthAnchor.constraint(equalToConstant: 24),
      image.heightAnchor.constraint(equalToConstant: 24),
      image.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
      image.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
    ])
    card.addArrangedSubview(circle)
    let title = coastLabel(
      name, size: 13, weight: .semibold, color: badge.unlocked ? CoastStyle.ink : CoastStyle.muted)
    title.textAlignment = .center
    card.addArrangedSubview(title)
    let detail = badge.unlocked
      ? (badge.at.isEmpty ? env.t("Unlocked", "已达成") : badge.at)
      : hint
    let sub = coastLabel(detail, size: 11, color: CoastStyle.muted)
    sub.textAlignment = .center
    card.addArrangedSubview(sub)
    card.isAccessibilityElement = true
    card.accessibilityLabel =
      name + ", " + (badge.unlocked ? env.t("unlocked", "已达成") : env.t("locked", "未达成")) + ", "
      + detail
    return card
  }
}
