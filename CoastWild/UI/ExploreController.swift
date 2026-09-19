import UIKit

final class ExploreController: CoastController {
  override func viewDidLoad() {
    super.viewDidLoad()
    title = nil
    navigationItem.rightBarButtonItem = iconItem("user", label: env.t("Your space", "个人空间")) {
      [weak self] in
      guard let self else { return }
      self.push(ProfileController(self.env))
    }
    render()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if isViewLoaded { render() }
  }
  func render() {
    reset()
    heading(env.t("Explore", "探索"))
    add(
      fieldButton(
        icon: "globe",
        title: env.t("Region · ", "内容地区 · ")
          + (env.store.preferences.region == "CN"
            ? env.t("Mainland China", "中国大陆") : env.t("United States", "美国"))
      ) { [weak self] in
        guard let self else { return }
        self.push(PreferencesController(self.env))
      })
    let search = fieldButton(
      icon: "search", title: env.t("Destinations, stories & experiences", "目的地、故事与体验")
    ) { [weak self] in
      guard let self else { return }
      self.push(SearchController(self.env))
    }
    search.accessibilityIdentifier = "explore.search"
    add(search)
    add(
      imageButton(
        image: "surf-coast", height: 248, accessibilityLabel: env.t("Explore the coast", "探索海岸")
      ) {
        [weak self] in
        guard let self, let item = self.env.item("coastal-story") else { return }
        self.push(ContentController(self.env, item: item))
      })
    add(coastLabel(env.t("Leave the weekend to the coast", "把周末留给海岸"), size: 23, weight: .semibold))
    note(env.t("Coastal walks, surf culture and time outdoors.", "海岸漫步、冲浪文化与户外夜晚。"))
    add(coastLabel(env.t("Find your next experience", "发现下一段体验"), size: 21, weight: .semibold))
    let featured = UIStackView()
    featured.axis = .horizontal
    featured.spacing = 12
    featured.distribution = .fillEqually
    for id in ["headlands", "trail-notes"] {
      if let item = env.item(id) {
        featured.addArrangedSubview(imageTile(item))
      }
    }
    add(featured)
    for id in ["shoreline", "pine-camp"] {
      if let item = env.item(id) {
        add(
          row(title: env.text(item.title), subtitle: env.text(item.subtitle), image: item.image) {
            [weak self] in
            guard let self else { return }
            self.push(ContentController(self.env, item: item))
          })
      }
    }
    note(
      env.t(
        "Original sample content. Check local access before making real travel plans.",
        "原创示例内容。实际出行前请核实当地开放信息。"))
  }
  private func fieldButton(icon: String, title: String, action: @escaping () -> Void) -> UIButton {
    let button = UIButton(type: .system)
    var config = UIButton.Configuration.plain()
    config.image = UIImage(named: "icon-" + icon)
    config.imagePadding = 10
    config.title = title
    config.baseForegroundColor = CoastStyle.ink
    config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
    config.titleAlignment = .leading
    button.configuration = config
    button.contentHorizontalAlignment = .leading
    button.backgroundColor = CoastStyle.field
    button.layer.cornerRadius = 10
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }
  private func imageButton(
    image: String, height: CGFloat, accessibilityLabel: String, action: @escaping () -> Void
  ) -> UIButton {
    let button = UIButton(type: .custom)
    button.clipsToBounds = true
    button.layer.cornerRadius = 16
    button.heightAnchor.constraint(equalToConstant: height).isActive = true
    button.accessibilityLabel = accessibilityLabel
    let photo = UIImageView(image: UIImage(named: image))
    photo.contentMode = .scaleAspectFill
    photo.clipsToBounds = true
    photo.translatesAutoresizingMaskIntoConstraints = false
    photo.isUserInteractionEnabled = false
    button.addSubview(photo)
    NSLayoutConstraint.activate([
      photo.topAnchor.constraint(equalTo: button.topAnchor),
      photo.leadingAnchor.constraint(equalTo: button.leadingAnchor),
      photo.trailingAnchor.constraint(equalTo: button.trailingAnchor),
      photo.bottomAnchor.constraint(equalTo: button.bottomAnchor),
    ])
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    return button
  }
  private func imageTile(_ item: CoastContent) -> UIButton {
    let button = imageButton(
      image: item.image, height: 160, accessibilityLabel: env.text(item.title)
    ) { [weak self] in
      guard let self else { return }
      self.push(ContentController(self.env, item: item))
    }
    let title = coastLabel(env.text(item.title), size: 16, weight: .semibold, color: .white)
    title.backgroundColor = UIColor.black.withAlphaComponent(0.48)
    title.textAlignment = .center
    title.translatesAutoresizingMaskIntoConstraints = false
    title.isUserInteractionEnabled = false
    button.addSubview(title)
    NSLayoutConstraint.activate([
      title.leadingAnchor.constraint(equalTo: button.leadingAnchor),
      title.trailingAnchor.constraint(equalTo: button.trailingAnchor),
      title.bottomAnchor.constraint(equalTo: button.bottomAnchor),
      title.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
    ])
    return button
  }
}
final class SearchController: CoastController, UISearchBarDelegate {
  var query = "", category = "", maximum = 0
  let results = UIStackView()
  let search = UISearchBar()
  let categoryControl = UISegmentedControl()
  override func viewDidLoad() {
    super.viewDidLoad()
    title = env.t("Search", "搜索")
    search.placeholder = env.t("Search outdoor stories", "搜索户外内容")
    search.searchBarStyle = .minimal
    search.delegate = self
    add(search)
    [env.t("All", "全部"), env.t("Surf", "冲浪"), env.t("Hiking", "徒步"), env.t("Camping", "露营")]
      .forEach {
        categoryControl.insertSegment(
          withTitle: $0, at: categoryControl.numberOfSegments, animated: false)
      }
    categoryControl.selectedSegmentIndex = 0
    categoryControl.selectedSegmentTintColor = CoastStyle.brand
    categoryControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
    categoryControl.setTitleTextAttributes([.foregroundColor: CoastStyle.ink], for: .normal)
    categoryControl.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
    categoryControl.addAction(
      UIAction { [weak self] _ in
        guard let self else { return }
        self.category = ["", "surf", "hike", "camp"][self.categoryControl.selectedSegmentIndex]
        self.renderResults()
      }, for: .valueChanged)
    add(categoryControl)
    navigationItem.rightBarButtonItem = iconItem("filter", label: env.t("Filter", "筛选")) {
      [weak self] in self?.filters()
    }
    results.axis = .vertical
    results.spacing = 18
    add(results)
    renderResults()
  }
  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    renderResults()
  }
  func filters() {
    menu(
      env.t("Duration", "时长"),
      choices: [
        (
          env.t("Any duration", "不限时长"),
          { [weak self] in
            self?.maximum = 0
            self?.renderResults()
          }
        ),
        (
          env.t("Up to 60 minutes", "60 分钟以内"),
          { [weak self] in
            self?.maximum = 60
            self?.renderResults()
          }
        ),
        (
          env.t("Up to 120 minutes", "120 分钟以内"),
          { [weak self] in
            self?.maximum = 120
            self?.renderResults()
          }
        ),
      ])
  }
  func renderResults() {
    results.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let items = env.catalog.items.filter { item in
      (category.isEmpty || category == item.category) && (maximum == 0 || item.minutes <= maximum)
        && (query.isEmpty
          || Array(item.title.values).joined(separator: " ").localizedCaseInsensitiveContains(query)
          || env.category(item.category).localizedCaseInsensitiveContains(query))
    }
    results.addArrangedSubview(
      coastLabel("\(items.count) " + env.t("results", "项结果"), size: 13, color: CoastStyle.muted))
    if items.isEmpty {
      results.addArrangedSubview(
        coastLabel(
          env.t("No results yet. Try another word or clear your filters.", "没有找到相关内容，试试其他关键词或清除筛选。")
        ))
      results.addArrangedSubview(
        coastButton(env.t("Clear filters", "清除筛选")) { [weak self] in
          self?.category = ""
          self?.maximum = 0
          self?.query = ""
          self?.search.text = ""
          self?.categoryControl.selectedSegmentIndex = 0
          self?.renderResults()
        })
    }
    items.forEach { item in
      results.addArrangedSubview(
        row(
          title: env.text(item.title),
          subtitle: env.category(item.category) + " · \(item.minutes) " + env.t("min", "分钟"),
          image: item.image
        ) { [weak self] in
          guard let self else { return }
          self.push(ContentController(self.env, item: item))
        })
    }
  }
}
final class ContentController: CoastController {
  let item: CoastContent
  init(_ env: CoastEnvironment, item: CoastContent) {
    self.item = item
    super.init(env)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    render()
  }
  func render() {
    reset()
    title = env.t("Explore", "探索")
    navigationItem.rightBarButtonItem = iconItem("bookmark", label: env.t("Save content", "收藏内容")) {
      [weak self] in
      guard let self else { return }
      if self.save({ try self.env.store.toggleBookmark(self.item.key) }) { self.render() }
    }
    navigationItem.rightBarButtonItem?.tintColor =
      env.store.ledger.bookmarks.contains(item.key) ? CoastStyle.sand : CoastStyle.brand
    add(coastImage(item.image, height: 280))
    heading(env.text(item.title))
    note(env.text(item.subtitle))
    if env.store.ledger.bookmarks.contains(item.key) {
      note(env.t("Saved to your collection", "已加入收藏"))
    }
    if let distance = item.distanceKm {
      let imperial = env.store.preferences.distanceUnit == "mi"
      add(
        coastLabel(
          String(
            format: "%.1f %@ · %d %@", imperial ? distance / 1.609344 : distance,
            imperial ? "mi" : "km", item.minutes, env.t("min", "分钟")), size: 17, weight: .medium))
    }
    add(
      coastLabel(
        item.body.map { env.text($0) }
          ?? env.t(
            "Take your time along the coast. Choose a comfortable pace and leave room to notice the landscape. This is an illustrative experience, not a navigation guide.",
            "沿着海岸慢慢前行，选择舒服的节奏，留意沿途风景。这是一份体验示例，不是实际导航指南。")))
    if item.kind != "story" {
      add(coastLabel(env.t("About this experience", "关于这次体验"), size: 20, weight: .semibold))
      note(
        env.t(
          "Check access, weather and local guidance before you go. Bring water and carry your litter out.",
          "出发前核实开放情况、天气与当地指引。带好饮水，并带走自己的垃圾。"))
    }
    add(coastButton(env.t("Add to trip", "加入出游")) { [weak self] in self?.chooseTrip() })
    add(coastLabel(env.t("A little more to explore", "开始一次小探索"), size: 21, weight: .semibold))
    env.catalog.items.filter { $0.key != item.key && $0.kind == "experience" }.prefix(2).forEach {
      related in
      add(
        row(
          title: env.text(related.title), subtitle: env.text(related.subtitle), image: related.image
        ) { [weak self] in
          guard let self else { return }
          self.push(ContentController(self.env, item: related))
        })
    }
  }
  func chooseTrip() {
    let trips = env.store.ledger.trips.filter { !$0.completed }
    if trips.isEmpty {
      push(TripEditorController(env, trip: nil, pending: item.key))
      return
    }
    menu(
      env.t("Choose a trip", "选择出游"),
      choices: trips.map { trip in
        (
          trip.name,
          { [weak self] in
            guard let self else { return }
            self.push(ActivityPickerController(self.env, tripID: trip.id, pending: self.item.key))
          }
        )
      } + [
        (
          env.t("Create trip", "创建出游"),
          { [weak self] in
            guard let self else { return }
            self.push(TripEditorController(self.env, trip: nil, pending: self.item.key))
          }
        )
      ])
  }
}
final class BookmarksController: CoastController {
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    render()
  }
  func render() {
    reset()
    title = env.t("Saved", "收藏")
    let items = env.catalog.items.filter { env.store.ledger.bookmarks.contains($0.key) }
    if items.isEmpty {
      empty(
        env.t("Keep what inspires you", "收藏喜欢的户外灵感"),
        env.t("Saved stories and places will appear here.", "喜欢的专题、地点与体验会出现在这里。"), icon: "bookmark")
    }
    items.forEach { item in
      add(
        row(title: env.text(item.title), subtitle: env.text(item.subtitle), image: item.image) {
          [weak self] in
          guard let self else { return }
          self.push(ContentController(self.env, item: item))
        })
    }
  }
}
