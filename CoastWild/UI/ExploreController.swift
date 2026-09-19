import UIKit

private func exploreLabel(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = CoastStyle.ink, lineHeight: CGFloat? = nil) -> UILabel {
  let label = coastLabel(text, size: size, weight: weight, color: color)
  guard let lineHeight else { return label }
  let paragraph = NSMutableParagraphStyle()
  paragraph.minimumLineHeight = lineHeight
  paragraph.maximumLineHeight = lineHeight
  let attributed = NSMutableAttributedString(attributedString: label.attributedText ?? NSAttributedString(string: text))
  attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))
  label.attributedText = attributed
  return label
}

private func explorePhoto(_ name: String, height: CGFloat, radius: CGFloat = 16) -> UIImageView {
  let image = UIImageView(image: UIImage(named: name))
  image.contentMode = .scaleAspectFill
  image.clipsToBounds = true
  image.layer.cornerRadius = radius
  image.heightAnchor.constraint(equalToConstant: height).isActive = true
  return image
}

final class ExploreController: CoastController {
  override func viewDidLoad() { super.viewDidLoad(); title = nil; render() }
  override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); if isViewLoaded { render() } }

  func render() {
    reset()
    let header = UIStackView()
    header.axis = .horizontal
    header.alignment = .center
    header.addArrangedSubview(exploreLabel(env.t("Explore", "探索"), size: 32, weight: .bold, lineHeight: 35.84))
    header.addArrangedSubview(UIView())
    let profile = UIButton(type: .system)
    profile.setImage(UIImage(named: "icon-user"), for: .normal)
    profile.tintColor = CoastStyle.brand
    profile.widthAnchor.constraint(equalToConstant: 44).isActive = true
    profile.heightAnchor.constraint(equalToConstant: 44).isActive = true
    profile.accessibilityLabel = env.t("Your space", "个人空间")
    profile.addAction(UIAction { [weak self] _ in guard let self else { return }; self.push(ProfileController(self.env)) }, for: .touchUpInside)
    header.addArrangedSubview(profile)
    add(header)
    stack.setCustomSpacing(10, after: header)

    let region = fieldButton(icon: "globe", title: env.store.preferences.region == "CN" ? env.t("Mainland China", "中国大陆") : env.t("United States", "美国"), filled: true, height: 42) { [weak self] in
      guard let self else { return }; self.push(PreferencesController(self.env))
    }
    add(region)
    stack.setCustomSpacing(12, after: region)
    let search = fieldButton(icon: "search", title: env.t("Places, stories, experiences", "目的地、故事与体验"), filled: true, height: 46) { [weak self] in
      guard let self else { return }; self.push(SearchController(self.env))
    }
    search.accessibilityIdentifier = "explore.search"
    add(search)
    stack.setCustomSpacing(15, after: search)

    let feature = UIStackView()
    feature.axis = .vertical
    feature.spacing = 7
    let hero = imageButton(image: "surf-coast", height: 244, label: env.t("A weekend by the water", "把周末留给海岸")) { [weak self] in
      guard let self, let item = self.env.item("coastal-story") else { return }; self.push(ContentController(self.env, item: item))
    }
    feature.addArrangedSubview(hero)
    feature.addArrangedSubview(exploreLabel(env.t("A weekend by the water", "把周末留给海岸"), size: 23, weight: .bold, lineHeight: 27.6))
    feature.addArrangedSubview(exploreLabel(env.t("Surf culture, coastal walks and a night outdoors.", "海岸漫步、冲浪文化与户外夜晚。"), size: 14, color: CoastStyle.muted, lineHeight: 19.6))
    add(feature)
    stack.setCustomSpacing(20, after: feature)
    let section = exploreLabel(env.t("Find your next experience", "发现下一段体验"), size: 21, weight: .bold, lineHeight: 25.2)
    add(section)
    stack.setCustomSpacing(12, after: section)
    let tiles = UIStackView()
    tiles.axis = .horizontal
    tiles.spacing = 12
    tiles.distribution = .fillEqually
    [("headlands", env.t("Coastal days", "海岸时光")), ("trail-notes", env.t("Into the hills", "走进山野"))].forEach { id, title in
      if let item = env.item(id) { tiles.addArrangedSubview(imageTile(item, title: title)) }
    }
    add(tiles)
  }

  private func fieldButton(icon: String, title: String, filled: Bool, height: CGFloat, action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system)
    var config = UIButton.Configuration.plain()
    config.image = UIImage(named: "icon-" + icon)
    config.imagePadding = 10
    config.title = title
    config.baseForegroundColor = filled ? CoastStyle.muted : .black
    config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
    config.titleAlignment = .leading
    button.configuration = config
    button.contentHorizontalAlignment = .leading
    button.backgroundColor = filled ? CoastStyle.field : .clear
    button.layer.cornerRadius = filled ? (height == 46 ? 12 : 10) : 0
    button.heightAnchor.constraint(equalToConstant: height).isActive = true
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }

  private func imageButton(image: String, height: CGFloat, label: String, action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .custom)
    button.clipsToBounds = true
    button.layer.cornerRadius = 16
    button.heightAnchor.constraint(equalToConstant: height).isActive = true
    button.accessibilityLabel = label
    let photo = explorePhoto(image, height: height)
    photo.translatesAutoresizingMaskIntoConstraints = false
    photo.isUserInteractionEnabled = false
    button.addSubview(photo)
    NSLayoutConstraint.activate([photo.topAnchor.constraint(equalTo: button.topAnchor), photo.leadingAnchor.constraint(equalTo: button.leadingAnchor), photo.trailingAnchor.constraint(equalTo: button.trailingAnchor), photo.bottomAnchor.constraint(equalTo: button.bottomAnchor)])
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }

  private func imageTile(_ item: CoastContent, title: String) -> UIButton {
    let button = imageButton(image: item.image, height: 155, label: title) { [weak self] in guard let self else { return }; self.push(ContentController(self.env, item: item)) }
    let shade = UIView()
    shade.backgroundColor = UIColor.black.withAlphaComponent(0.36)
    shade.translatesAutoresizingMaskIntoConstraints = false
    shade.isUserInteractionEnabled = false
    button.addSubview(shade)
    let label = exploreLabel(title, size: 14, weight: .bold, color: .white)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.isUserInteractionEnabled = false
    button.addSubview(label)
    NSLayoutConstraint.activate([shade.leadingAnchor.constraint(equalTo: button.leadingAnchor), shade.trailingAnchor.constraint(equalTo: button.trailingAnchor), shade.bottomAnchor.constraint(equalTo: button.bottomAnchor), shade.heightAnchor.constraint(equalToConstant: 48), label.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 10), label.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -13)])
    return button
  }
}

final class SearchController: CoastController, UISearchBarDelegate {
  var query = "", category = "", maximum = 0
  let results = UIStackView(), search = UISearchBar(), categoryRow = UIStackView()
  override func viewDidLoad() {
    super.viewDidLoad()
    title = env.t("Search", "搜索")
    search.placeholder = env.t("Search the outdoors", "搜索户外内容")
    search.searchBarStyle = .minimal
    search.delegate = self
    let searchRow = UIStackView()
    searchRow.axis = .horizontal
    searchRow.alignment = .center
    searchRow.backgroundColor = CoastStyle.field
    searchRow.layer.cornerRadius = 12
    searchRow.addArrangedSubview(search)
    let filter = UIButton(type: .system)
    filter.setImage(UIImage(named: "icon-filter"), for: .normal)
    filter.tintColor = CoastStyle.brand
    filter.accessibilityLabel = env.t("Filter", "筛选")
    filter.widthAnchor.constraint(equalToConstant: 44).isActive = true
    filter.heightAnchor.constraint(equalToConstant: 44).isActive = true
    filter.addAction(UIAction { [weak self] _ in self?.filters() }, for: .touchUpInside)
    searchRow.addArrangedSubview(filter)
    searchRow.heightAnchor.constraint(equalToConstant: 48).isActive = true
    add(searchRow)
    categoryRow.axis = .horizontal
    categoryRow.spacing = 8
    categoryRow.alignment = .fill
    add(categoryRow)
    renderCategories()
    results.axis = .vertical
    results.spacing = 12
    add(results)
    renderResults()
  }
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { query = searchText.trimmingCharacters(in: .whitespacesAndNewlines); renderResults() }
  private func renderCategories() {
    categoryRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let values = [(env.t("All", "全部"), ""), (env.t("Surfing", "冲浪"), "surf"), (env.t("Hiking", "徒步"), "hike"), (env.t("Camping", "露营"), "camp")]
    values.forEach { title, value in
      let button = UIButton(type: .system)
      var config = UIButton.Configuration.filled()
      config.title = title
      config.baseBackgroundColor = category == value ? CoastStyle.brand : .white
      config.baseForegroundColor = category == value ? .white : CoastStyle.muted
      config.background.cornerRadius = 20
      config.background.strokeColor = category == value ? CoastStyle.brand : CoastStyle.border
      config.background.strokeWidth = 1
      config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 17, bottom: 10, trailing: 17)
      button.configuration = config
      button.heightAnchor.constraint(equalToConstant: 40).isActive = true
      button.addAction(UIAction { [weak self] _ in self?.category = value; self?.renderCategories(); self?.renderResults() }, for: .touchUpInside)
      categoryRow.addArrangedSubview(button)
    }
    categoryRow.addArrangedSubview(UIView())
  }
  func filters() {
    menu(env.t("Duration", "时长"), choices: [
      (env.t("Any duration", "不限时长"), { [weak self] in self?.maximum = 0; self?.renderResults() }),
      (env.t("Up to 60 minutes", "60 分钟以内"), { [weak self] in self?.maximum = 60; self?.renderResults() }),
      (env.t("Up to 120 minutes", "120 分钟以内"), { [weak self] in self?.maximum = 120; self?.renderResults() }),
    ])
  }
  func renderResults() {
    results.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let items = env.catalog.items.filter { item in
      (category.isEmpty || category == item.category) && (maximum == 0 || item.minutes <= maximum) && (query.isEmpty || Array(item.title.values).joined(separator: " ").localizedCaseInsensitiveContains(query) || env.category(item.category).localizedCaseInsensitiveContains(query))
    }
    results.addArrangedSubview(exploreLabel("\(items.count) " + env.t("results", "项结果"), size: 12, color: CoastStyle.muted, lineHeight: 18))
    if items.isEmpty {
      results.addArrangedSubview(exploreLabel(env.t("No results yet. Try another word or clear your filters.", "没有找到相关内容，试试其他关键词或清除筛选。"), size: 16))
      results.addArrangedSubview(coastButton(env.t("Clear filters", "清除筛选")) { [weak self] in self?.category = ""; self?.maximum = 0; self?.query = ""; self?.search.text = ""; self?.renderCategories(); self?.renderResults() })
    }
    items.forEach { results.addArrangedSubview(searchCard($0)) }
  }
  private func searchCard(_ item: CoastContent) -> UIView {
    let button = UIButton(type: .system)
    button.backgroundColor = .white
    button.layer.cornerRadius = 14
    button.layer.borderColor = CoastStyle.border.cgColor
    button.layer.borderWidth = 1
    button.heightAnchor.constraint(equalToConstant: 161).isActive = true
    let image = explorePhoto(item.image, height: 128, radius: 12)
    image.translatesAutoresizingMaskIntoConstraints = false
    button.addSubview(image)
    let text = UIStackView()
    text.axis = .vertical; text.spacing = 7; text.translatesAutoresizingMaskIntoConstraints = false; text.isUserInteractionEnabled = false
    text.addArrangedSubview(exploreLabel(env.text(item.title), size: 17, weight: .bold, lineHeight: 22.1))
    text.addArrangedSubview(exploreLabel(env.category(item.category) + " · \(item.minutes) " + env.t("min", "分钟"), size: 13, color: CoastStyle.muted, lineHeight: 18.85))
    button.addSubview(text)
    let chevron = UIImageView(image: UIImage(named: "icon-next"))
    chevron.tintColor = CoastStyle.muted
    chevron.contentMode = .scaleAspectFit
    chevron.translatesAutoresizingMaskIntoConstraints = false
    button.addSubview(chevron)
    NSLayoutConstraint.activate([image.leadingAnchor.constraint(equalTo: button.leadingAnchor), image.centerYAnchor.constraint(equalTo: button.centerYAnchor), image.widthAnchor.constraint(equalToConstant: 124), text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 13), text.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8), text.centerYAnchor.constraint(equalTo: button.centerYAnchor), chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12), chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor), chevron.widthAnchor.constraint(equalToConstant: 16), chevron.heightAnchor.constraint(equalToConstant: 24)])
    button.accessibilityIdentifier = "explore.result.\(item.key)"
    button.accessibilityLabel = [env.text(item.title), env.category(item.category), "\(item.minutes) " + env.t("min", "分钟")].joined(separator: ", ")
    button.addAction(UIAction { [weak self] _ in guard let self else { return }; self.push(ContentController(self.env, item: item)) }, for: .touchUpInside)
    return button
  }
}

final class ContentController: CoastController {
  let item: CoastContent
  init(_ env: CoastEnvironment, item: CoastContent) { self.item = item; super.init(env) }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() { super.viewDidLoad(); render() }
  func render() {
    reset(); title = nil
    navigationItem.rightBarButtonItem = iconItem("bookmark", label: env.t("Save content", "收藏内容")) { [weak self] in guard let self else { return }; if self.save({ try self.env.store.toggleBookmark(self.item.key) }) { self.render() } }
    navigationItem.rightBarButtonItem?.tintColor = env.store.ledger.bookmarks.contains(item.key) ? CoastStyle.sand : CoastStyle.brand
    if item.kind == "experience" { renderExperience(); return }
    add(explorePhoto(item.image, height: 238))
    if item.kind == "story" { add(exploreLabel(env.category(item.category).uppercased() + env.t(" · FIELD NOTES", " · 自然笔记"), size: 11, weight: .semibold, color: CoastStyle.brand)) }
    add(exploreLabel(env.text(item.title), size: 32, weight: .bold, lineHeight: 35.84))
    add(exploreLabel(env.text(item.subtitle), size: 16, color: CoastStyle.muted, lineHeight: 24))
    if item.kind == "story" {
      add(exploreLabel(item.body.map { env.text($0) } ?? "", size: 16, lineHeight: 26.4))
    } else {
      add(destinationFacts())
    }
    if item.kind == "story" {
      add(coastButton(env.t("Add to a trip", "加入出游")) { [weak self] in self?.chooseTrip() })
      add(exploreLabel(env.t("Try a little exploration", "开始一次小探索"), size: 23, weight: .bold, lineHeight: 27.6))
      env.catalog.items.filter { $0.key != item.key && $0.kind == "experience" }.prefix(1).forEach { add(detailRow($0)) }
    } else {
      add(exploreLabel(env.t("Make a day of it", "把一天交给自然"), size: 23, weight: .bold, lineHeight: 27.6))
      env.catalog.items.filter { $0.kind == "experience" }.prefix(3).forEach { add(detailRow($0)) }
      add(exploreLabel(env.t("An illustrative destination. Check local access and conditions before planning a real visit.", "此处为示例目的地。计划实际出行前，请核实当地开放情况与环境。"), size: 13, color: CoastStyle.muted, lineHeight: 20))
    }
  }
  private func renderExperience() {
    add(exploreLabel(env.text(item.title), size: 32, weight: .bold, lineHeight: 35.84))
    add(exploreLabel(env.text(item.subtitle), size: 16, color: CoastStyle.muted, lineHeight: 24))
    add(explorePhoto(item.image, height: 238)); add(metrics())
    add(exploreLabel(env.t("A little more about it", "关于这次体验"), size: 23, weight: .bold, lineHeight: 27.6))
    add(exploreLabel(env.t("Make space for an unhurried moment outside. Notice the view, enjoy the fresh air and keep a small memory of the day.", "为户外留一段不赶时间的片刻。观察风景，感受新鲜空气，留下一点属于今天的回忆。"), size: 16, lineHeight: 24))
    add(coastButton(env.t("Add to a trip", "加入出游")) { [weak self] in self?.chooseTrip() })
    add(exploreLabel(env.t("An example experience, not a navigation route. Check current access before leaving.", "此处为示例体验，不提供实时导航。出发前请核实开放情况。"), size: 13, color: CoastStyle.muted, lineHeight: 20))
  }
  private func destinationFacts() -> UIView {
    let row = UIStackView(); row.axis = .horizontal; row.distribution = .fillEqually
    [("wave", env.t("Coast", "海岸")), ("hike", env.t("Walks", "步道")), ("camp", env.t("Camp", "露营"))].forEach { icon, title in
      let group = UIStackView(); group.axis = .vertical; group.alignment = .center; group.spacing = 8
      let image = UIImageView(image: UIImage(named: "icon-" + icon)); image.tintColor = CoastStyle.brand; image.contentMode = .scaleAspectFit
      image.widthAnchor.constraint(equalToConstant: 24).isActive = true; image.heightAnchor.constraint(equalToConstant: 24).isActive = true
      group.addArrangedSubview(image); group.addArrangedSubview(exploreLabel(title, size: 13, color: CoastStyle.muted)); row.addArrangedSubview(group)
    }
    row.heightAnchor.constraint(equalToConstant: 72).isActive = true
    return row
  }
  private func metrics() -> UIView {
    let row = UIStackView(); row.axis = .horizontal; row.distribution = .fillEqually
    let imperial = env.store.preferences.distanceUnit == "mi"
    let distance = item.distanceKm.map { String(format: "%.1f %@", imperial ? $0 / 1.609344 : $0, imperial ? "mi" : "km") } ?? "—"
    [("\(item.minutes) " + env.t("min", "分钟"), env.t("Time", "时长")), (distance, env.t("Distance", "距离")), (env.t("Easy", "轻松"), env.t("Pace", "节奏"))].forEach { value, caption in
      let column = UIStackView(); column.axis = .vertical; column.alignment = .center; column.spacing = 4
      column.addArrangedSubview(exploreLabel(value, size: 18, weight: .bold)); column.addArrangedSubview(exploreLabel(caption, size: 13, color: CoastStyle.muted)); row.addArrangedSubview(column)
    }
    row.heightAnchor.constraint(equalToConstant: 76).isActive = true
    return row
  }
  private func detailRow(_ related: CoastContent) -> UIView {
    let button = UIButton(type: .system); button.backgroundColor = .white; button.layer.cornerRadius = 14; button.layer.borderColor = CoastStyle.border.cgColor; button.layer.borderWidth = 1; button.heightAnchor.constraint(equalToConstant: 114).isActive = true
    let image = explorePhoto(related.image, height: 90, radius: 10); image.translatesAutoresizingMaskIntoConstraints = false; button.addSubview(image)
    let text = UIStackView(); text.axis = .vertical; text.spacing = 7; text.translatesAutoresizingMaskIntoConstraints = false; text.isUserInteractionEnabled = false
    text.addArrangedSubview(exploreLabel(env.text(related.title), size: 17, weight: .bold, lineHeight: 22.1)); text.addArrangedSubview(exploreLabel(env.category(related.category) + " · \(related.minutes) " + env.t("min", "分钟"), size: 13, color: CoastStyle.muted, lineHeight: 18.85)); button.addSubview(text)
    let chevron = UIImageView(image: UIImage(named: "icon-next")); chevron.tintColor = CoastStyle.muted; chevron.contentMode = .scaleAspectFit; chevron.translatesAutoresizingMaskIntoConstraints = false; button.addSubview(chevron)
    NSLayoutConstraint.activate([image.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12), image.centerYAnchor.constraint(equalTo: button.centerYAnchor), image.widthAnchor.constraint(equalToConstant: 88), text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 13), text.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8), text.centerYAnchor.constraint(equalTo: button.centerYAnchor), chevron.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -12), chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor), chevron.widthAnchor.constraint(equalToConstant: 16), chevron.heightAnchor.constraint(equalToConstant: 24)])
    button.accessibilityIdentifier = "explore.related.\(related.key)"
    button.accessibilityLabel = [env.text(related.title), env.category(related.category), "\(related.minutes) " + env.t("min", "分钟")].joined(separator: ", ")
    button.addAction(UIAction { [weak self] _ in guard let self else { return }; self.push(ContentController(self.env, item: related)) }, for: .touchUpInside)
    return button
  }
  func chooseTrip() {
    let trips = env.store.ledger.trips.filter { !$0.completed }
    if trips.isEmpty { push(TripEditorController(env, trip: nil, pending: item.key)); return }
    menu(env.t("Choose a trip", "选择出游"), choices: trips.map { trip in (trip.name, { [weak self] in guard let self else { return }; self.push(ActivityPickerController(self.env, tripID: trip.id, pending: self.item.key)) }) } + [(env.t("Create trip", "创建出游"), { [weak self] in guard let self else { return }; self.push(TripEditorController(self.env, trip: nil, pending: self.item.key)) })])
  }
}

final class BookmarksController: CoastController {
  override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); render() }
  func render() {
    reset(); title = nil
    add(exploreLabel(env.t("Saved", "收藏"), size: 32, weight: .bold, lineHeight: 35.84))
    let items = env.catalog.items.filter { env.store.ledger.bookmarks.contains($0.key) }
    if items.isEmpty {
      empty(env.t("Keep what inspires you", "收藏喜欢的户外灵感"), env.t("Saved stories and places will appear here.", "喜欢的专题、地点与体验会出现在这里。"), icon: "bookmark", actionTitle: env.t("Start exploring", "开始探索")) { [weak self] in
        self?.tabBarController?.selectedIndex = 0
      }
    }
    items.forEach { item in add(row(title: env.text(item.title), subtitle: env.text(item.subtitle), image: item.image) { [weak self] in guard let self else { return }; self.push(ContentController(self.env, item: item)) }) }
  }
}
